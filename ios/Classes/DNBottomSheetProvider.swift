import UIKit
import FlexLayout

private func dnLog(_ msg: String) { print("[DNBottomSheet] \(msg)") }

// ─── Container View Controller with FlexLayout ──────────────────────────────

private final class _DNBottomSheetContainerViewController: UIViewController {
    weak var rootView: UIView?
    /// Explicit sheet background. When set, it wins and the child-bg scan is skipped.
    var explicitBackgroundColor: UIColor?
    /// When false (and no explicit color), keep the platform default instead of
    /// scanning the Dart view tree for a background color.
    var adaptToContainerBackground = true

    override func viewDidLoad() {
        super.viewDidLoad()
        if let explicit = explicitBackgroundColor {
            view.backgroundColor = explicit
        } else if adaptToContainerBackground {
            view.backgroundColor = .clear
        } else {
            view.backgroundColor = .systemBackground
        }
        view.clipsToBounds = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        layoutRootFlex()
        syncBackgroundColor()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        layoutRootFlex()
        syncBackgroundColor()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutRootFlex()
        syncBackgroundColor()
    }

    func syncBackgroundColor() {
        // Explicit color always wins — re-enforce it (UIKit may reset it).
        if let explicit = explicitBackgroundColor {
            view.backgroundColor = explicit
            return
        }
        // Opted out of the legacy child-bg scan: keep the platform default.
        if !adaptToContainerBackground { return }
        func findBg(in v: UIView?) -> UIColor? {
            guard let v = v else { return nil }
            if let bg = v.backgroundColor, bg != .clear, bg.cgColor.alpha > 0.05 {
                return bg
            }
            for sub in v.subviews {
                if let bg = findBg(in: sub) { return bg }
            }
            return nil
        }
        if let bg = findBg(in: rootView) {
            view.backgroundColor = bg
        }
    }

    func measureContentHeight(forWidth width: CGFloat) -> CGFloat {
        guard let rv = rootView else { return 0 }
        let targetWidth = width > 0 ? width : (view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width)
        rv.frame = CGRect(x: 0, y: 0, width: targetWidth, height: 0)
        rv.flex.layout(mode: .adjustHeight)
        let measured = rv.frame.height
        if view.bounds.height > 0 {
            rv.frame = view.bounds
            rv.flex.layout(mode: .fitContainer)
            _dnCATransactionCommit?()
        }
        return measured
    }

    func layoutRootFlex() {
        guard let rv = rootView else { return }
        rv.frame = view.bounds
        rv.flex.layout(mode: .fitContainer)
        _dnCATransactionCommit?()
        syncBackgroundColor()
        if #available(iOS 15.0, *) {
            if let sv = findScrollView(in: view) {
                setContentScrollView(sv, for: .top)
                navigationController?.setContentScrollView(sv, for: .top)
            }
        }
    }

    private func findScrollView(in v: UIView?) -> UIScrollView? {
        guard let v = v else { return nil }
        if let sv = v as? UIScrollView { return sv }
        for sub in v.subviews {
            if let sv = findScrollView(in: sub) { return sv }
        }
        return nil
    }

    @available(iOS 15.0, *)
    override func contentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView? {
        if edge == .top {
            return findScrollView(in: view)
        }
        return super.contentScrollView(for: edge)
    }
}

// ─── Dispatcher slot (standard pattern from plugin_async_callbacks.md) ──────

private let _dispatcherSlot: UnsafeMutablePointer<Int64> = {
    let p = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
    p.pointee = 0
    return p
}()
private var _slotRegistered = false

private typealias _DispatchFn = @convention(c) (Int64, Int32, UnsafePointer<CChar>) -> Void

private func fireToDart(token: Int64, type: Int32, payload: String) {
    // MUST run on main thread. Native callbacks from UIKit delegate are already
    // on main, but guard for safety.
    assert(Thread.isMainThread, "fireToDart must be called on the main thread")
    let addr = _dispatcherSlot.pointee   // read FRESH every time — never cache
    guard addr != 0 else { return }      // hot restart happened → drop quietly
    payload.withCString { cStr in
        unsafeBitCast(addr, to: _DispatchFn.self)(token, type, cStr)
    }
}

// ─── Event type constants (must match ffi_bindings.dart) ────────────────────

private let kEventDetentChanged:    Int32 = 1
private let kEventDismissed:        Int32 = 2
private let kEventDismissAttempted: Int32 = 3
private let kEventPresented:        Int32 = 4

// ─── Active sheets registry ─────────────────────────────────────────────────

private var _activeSheets: [Int64: _SheetEntry] = [:]

private final class _SheetEntry {
    let sheetId: Int64
    let rootViewId: Int64
    let presentingVC: UIViewController  // the VC that called present()
    let containerVC: _DNBottomSheetContainerViewController   // the VC we presented (holds sheet)
    let navController: UINavigationController?  // non-nil when routerEnabled
    let detents: [_DetentSpec]
    var isDismissing = false

    init(
        sheetId: Int64,
        rootViewId: Int64,
        presentingVC: UIViewController,
        containerVC: _DNBottomSheetContainerViewController,
        navController: UINavigationController?,
        detents: [_DetentSpec]
    ) {
        self.sheetId = sheetId
        self.rootViewId = rootViewId
        self.presentingVC = presentingVC
        self.containerVC = containerVC
        self.navController = navController
        self.detents = detents
    }
}

// ─── Detent parsing ──────────────────────────────────────────────────────────

private enum _DetentSpec {
    case named(String)          // "medium" | "large" | "contentFit"
    case fraction(Double)
    case pixels(Double)

    @available(iOS 15, *)
    func uiDetent(identifier: UISheetPresentationController.Detent.Identifier,
                  contentVC: UIViewController?) -> UISheetPresentationController.Detent {
        switch self {
        case .named(let n) where n == "medium":
            return .medium()
        case .named(let n) where n == "large":
            return .large()
        case .named(let n) where n == "contentFit":
            if #available(iOS 16, *) {
                return .custom(identifier: identifier) { [weak contentVC] ctx in
                    guard let container = contentVC as? _DNBottomSheetContainerViewController else {
                        return ctx.maximumDetentValue
                    }
                    let sheetWidth = container.view.window?.bounds.width ?? container.view.bounds.width
                    let targetWidth = sheetWidth > 0 ? sheetWidth : UIScreen.main.bounds.width
                    let measured = container.measureContentHeight(forWidth: targetWidth)
                    if measured > 0 {
                        return min(measured, ctx.maximumDetentValue)
                    }
                    return ctx.maximumDetentValue
                }
            }
            return .large()  // iOS 15 fallback
        case .fraction(let f):
            if #available(iOS 16, *) {
                return .custom(identifier: identifier) { ctx in
                    ctx.maximumDetentValue * CGFloat(f)
                }
            }
            return f < 0.6 ? .medium() : .large()  // iOS 15 fallback
        case .pixels(let h):
            if #available(iOS 16, *) {
                return .custom(identifier: identifier) { _ in CGFloat(h) }
            }
            // iOS 15 fallback: compare to half of screen height
            let halfScreen = UIScreen.main.bounds.height / 2
            return h < halfScreen ? .medium() : .large()
        default:
            return .large()
        }
    }

    // Map detent spec to its Identifier for selectedDetentIdentifier
    @available(iOS 15, *)
    func identifier(at index: Int) -> UISheetPresentationController.Detent.Identifier {
        switch self {
        case .named(let n) where n == "medium": return .medium
        case .named(let n) where n == "large":  return .large
        default:
            return UISheetPresentationController.Detent.Identifier("dn.custom.\(index)")
        }
    }
}

private func parseDetent(from dict: [String: Any]) -> _DetentSpec {
    let type = dict["type"] as? String ?? "named"
    switch type {
    case "named":
        return .named(dict["name"] as? String ?? "large")
    case "fraction":
        return .fraction(dict["value"] as? Double ?? 1.0)
    case "pixels":
        return .pixels(dict["value"] as? Double ?? 400)
    default:
        return .named("large")
    }
}

// ─── JSON parsing helper ─────────────────────────────────────────────────────

private func parseJSON(_ cStr: UnsafePointer<CChar>) -> [String: Any]? {
    guard let data = String(cString: cStr).data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return obj
}

// ─── DNViewRegistry helper (dlsym — no circular dep) ────────────────────────

private typealias _CreateViewFn = @convention(c) (Int32) -> Int64
private let _dnCreateView: _CreateViewFn? = {
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNUIViewCreate") else { return nil }
    return unsafeBitCast(s, to: _CreateViewFn.self)
}()

private typealias _DisposeViewFn = @convention(c) (Int64) -> Void
private let _dnDisposeView: _DisposeViewFn? = {
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNUIViewDispose") else { return nil }
    return unsafeBitCast(s, to: _DisposeViewFn.self)
}()

private typealias _GetViewFn = @convention(c) (Int64) -> Int64
private let _dnGetView: _GetViewFn? = {
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNViewRegistryGetView") else { return nil }
    return unsafeBitCast(s, to: _GetViewFn.self)
}()
private func _viewFor(_ id: Int64) -> UIView? {
    guard let fn = _dnGetView, id != 0 else { return nil }
    let p = fn(id); guard p != 0 else { return nil }
    return Unmanaged<UIView>.fromOpaque(UnsafeRawPointer(bitPattern: Int(p))!)
        .takeUnretainedValue()
}

private typealias _CATransactionCommitFn = @convention(c) () -> Void
private let _dnCATransactionCommit: _CATransactionCommitFn? = {
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNCATransactionCommit") else { return nil }
    return unsafeBitCast(s, to: _CATransactionCommitFn.self)
}()

// ── Find front-most presenting VC ──────────────────────────────────────────

private func frontVC() -> UIViewController? {
    guard let root = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: \.isKeyWindow)?
        .rootViewController
    else { return nil }
    var vc: UIViewController = root
    while let p = vc.presentedViewController { vc = p }
    return vc
}

// ─── Sheet delegate ──────────────────────────────────────────────────────────

@available(iOS 15, *)
private final class _SheetDelegate: NSObject,
    UISheetPresentationControllerDelegate,
    UIAdaptivePresentationControllerDelegate
{
    let sheetId: Int64
    let detents: [_DetentSpec]
    var isDismissable: Bool

    init(sheetId: Int64, detents: [_DetentSpec], isDismissable: Bool) {
        self.sheetId = sheetId
        self.detents = detents
        self.isDismissable = isDismissable
    }

    // Detent changed
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheet: UISheetPresentationController
    ) {
        guard let id = sheet.selectedDetentIdentifier else { return }
        // Find which index the new identifier corresponds to
        let idx = detents.indices.first {
            detents[$0].identifier(at: $0) == id
        } ?? -1
        fireToDart(token: sheetId, type: kEventDetentChanged,
                   payload: "{\"detentIndex\":\(idx)}")
    }

    // Sync dismiss veto — presentationControllerShouldDismiss
    func presentationControllerShouldDismiss(
        _ presentationController: UIPresentationController
    ) -> Bool {
        return isDismissable
    }

    // Fired when dismiss was blocked (isModalInPresentation = true)
    func presentationControllerDidAttemptToDismiss(
        _ presentationController: UIPresentationController
    ) {
        fireToDart(token: sheetId, type: kEventDismissAttempted, payload: "{}")
    }

    // Fired after dismiss completes
    func presentationControllerDidDismiss(
        _ presentationController: UIPresentationController
    ) {
        if let entry = _activeSheets.removeValue(forKey: sheetId) {
            _dnDisposeView?(entry.rootViewId)
        }
        _delegates.removeValue(forKey: sheetId)
        fireToDart(token: sheetId, type: kEventDismissed, payload: "{}")
    }
}

// ─── Delegate storage (keyed by sheetId, retained for lifetime of sheet) ─────
private var _delegates: [Int64: AnyObject] = [:]

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - @_cdecl exports
// ─────────────────────────────────────────────────────────────────────────────

/// Called once by Dart's loadSymbols(). Re-called on hot restart with the new
/// session's dispatcher pointer — we use this to dismiss any zombie sheets.
@_cdecl("DNBottomSheetSetDispatcher")
public func DNBottomSheetSetDispatcher(_ callbackPtr: Int64) {
    // ── Hot restart cleanup ────────────────────────────────────────────────
    // At this point the old slot is already 0 (framework zeroed it before the
    // old pointer died), so dismissing without firing Dart events is safe.
    if !_activeSheets.isEmpty {
        let sheets = Array(_activeSheets.values)
        _activeSheets.removeAll()
        _delegates.removeAll()
        DispatchQueue.main.async {
            for entry in sheets {
                _dnDisposeView?(entry.rootViewId)
                entry.containerVC.dismiss(animated: false, completion: nil)
            }
        }
    }

    // ── Register fresh slot ────────────────────────────────────────────────
    _dispatcherSlot.pointee = callbackPtr
    if !_slotRegistered {
        _slotRegistered = true
        typealias RegFn = @convention(c) (UnsafeMutablePointer<Int64>) -> Void
        if let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2),
                           "DNRegisterAsyncDispatcherSlot") {
            unsafeBitCast(sym, to: RegFn.self)(_dispatcherSlot)
        }
    }
}

/// Present a sheet. JSON payload matches the wire format in the plan.
/// Returns the root view ID for mounting the Dart widget tree reconciler.
@_cdecl("DNBottomSheetShow")
public func DNBottomSheetShow(_ jsonCStr: UnsafePointer<CChar>) -> Int64 {
    guard #available(iOS 15, *) else {
        dnLog("DNBottomSheetShow: requires iOS 15+")
        return 0
    }
    guard let cfg = parseJSON(jsonCStr) else {
        dnLog("DNBottomSheetShow: failed to parse JSON")
        return 0
    }

    let sheetId    = (cfg["sheetId"]       as? Int64) ?? Int64(cfg["sheetId"] as? Int ?? 0)
    let detentDicts = cfg["detents"]       as? [[String: Any]] ?? []
    let initIdx    = cfg["initialDetentIndex"] as? Int ?? 0
    let showGrabber  = cfg["showGrabber"]  as? Bool ?? true
    let cornerRadius = cfg["cornerRadius"] as? CGFloat
    let scrimOpacity = cfg["scrimOpacity"] as? CGFloat
    let isDismissable  = cfg["isDismissable"]    as? Bool ?? true
    let scrollExpands  = cfg["scrollExpandsSheet"] as? Bool ?? true
    let routerEnabled  = cfg["routerEnabled"]     as? Bool ?? false
    let adaptBg = cfg["adaptToContainerBackground"] as? Bool ?? true
    // 0xAARRGGBB (may arrive as signed Int from Dart) → UIColor.
    var explicitBg: UIColor?
    if let n = cfg["backgroundColor"] as? Int {
        let u = UInt32(truncatingIfNeeded: Int64(n))
        let a = CGFloat((u >> 24) & 0xFF) / 255.0
        let r = CGFloat((u >> 16) & 0xFF) / 255.0
        let g = CGFloat((u >> 8) & 0xFF) / 255.0
        let b = CGFloat(u & 0xFF) / 255.0
        explicitBg = UIColor(red: r, green: g, blue: b, alpha: a)
    } else if let n = cfg["backgroundColor"] as? Int64 {
        let u = UInt32(truncatingIfNeeded: n)
        let a = CGFloat((u >> 24) & 0xFF) / 255.0
        let r = CGFloat((u >> 16) & 0xFF) / 255.0
        let g = CGFloat((u >> 8) & 0xFF) / 255.0
        let b = CGFloat(u & 0xFF) / 255.0
        explicitBg = UIColor(red: r, green: g, blue: b, alpha: a)
    }

    let iosCfg     = cfg["ios"] as? [String: Any] ?? [:]
    let undimmedIdx = iosCfg["largestUndimmedDetentIndex"] as? Int ?? -1
    let edgeAttached    = iosCfg["edgeAttachedInCompactHeight"] as? Bool ?? false
    let widthFollows    = iosCfg["widthFollowsContentSizeWhenEdgeAttached"] as? Bool ?? false
    let prefersPageSz   = iosCfg["prefersPageSizing"] as? Bool ?? true

    let detents = detentDicts.map { parseDetent(from: $0) }

    guard let presenter = frontVC() else {
        dnLog("DNBottomSheetShow: could not find front VC")
        return 0
    }

    // Allocate root DNView for Dart content
    let rootViewId = _dnCreateView?(0) ?? 0
    let dartRootView = _viewFor(rootViewId)

    // Pre-calculate target bounds from presenter/screen so initial Yoga layout pass
    // never runs against a 0x0 frame.
    let screenBounds = presenter.view.window?.bounds ?? presenter.view.bounds
    let targetWidth = screenBounds.width > 0 ? screenBounds.width : UIScreen.main.bounds.width
    let targetHeight: CGFloat
    if let firstDetent = detents.first {
        switch firstDetent {
        case .named(let n) where n == "medium":
            targetHeight = (screenBounds.height > 0 ? screenBounds.height : UIScreen.main.bounds.height) * 0.5
        case .named(let n) where n == "large":
            targetHeight = (screenBounds.height > 0 ? screenBounds.height : UIScreen.main.bounds.height) * 0.9
        case .fraction(let f):
            targetHeight = (screenBounds.height > 0 ? screenBounds.height : UIScreen.main.bounds.height) * CGFloat(f)
        case .pixels(let p):
            targetHeight = CGFloat(p)
        default:
            targetHeight = (screenBounds.height > 0 ? screenBounds.height : UIScreen.main.bounds.height) * 0.5
        }
    } else {
        targetHeight = (screenBounds.height > 0 ? screenBounds.height : UIScreen.main.bounds.height) * 0.5
    }

    // Container VC that will hold the Dart content view with FlexLayout.
    let containerVC = _DNBottomSheetContainerViewController()
    containerVC.rootView = dartRootView
    containerVC.explicitBackgroundColor = explicitBg
    containerVC.adaptToContainerBackground = adaptBg
    containerVC.view.frame = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
    containerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    if let rv = dartRootView {
        containerVC.view.addSubview(rv)
        rv.frame = containerVC.view.bounds
        rv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerVC.layoutRootFlex()
    }

    // Optionally wrap in a navigation controller for sheet routing.
    let presentedVC: UIViewController
    var navController: UINavigationController?
    if routerEnabled {
        let nav = UINavigationController(rootViewController: containerVC)
        nav.setNavigationBarHidden(true, animated: false)
        navController = nav
        presentedVC = nav
    } else {
        presentedVC = containerVC
    }

    presentedVC.modalPresentationStyle = .pageSheet
    presentedVC.isModalInPresentation = !isDismissable

    guard let sheet = presentedVC.sheetPresentationController else {
        dnLog("DNBottomSheetShow: no sheetPresentationController")
        return rootViewId
    }

    // ── Detents ──────────────────────────────────────────────────────
    sheet.detents = detents.enumerated().map { (i, spec) in
        spec.uiDetent(
            identifier: spec.identifier(at: i),
            contentVC: containerVC
        )
    }
    if initIdx < detents.count {
        sheet.selectedDetentIdentifier = detents[initIdx].identifier(at: initIdx)
    }

    // ── Appearance ───────────────────────────────────────────────────
    sheet.prefersGrabberVisible             = showGrabber
    sheet.preferredCornerRadius             = cornerRadius
    sheet.prefersScrollingExpandsWhenScrolledToEdge = scrollExpands
    sheet.prefersEdgeAttachedInCompactHeight = edgeAttached
    sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = widthFollows

    if undimmedIdx >= 0 && undimmedIdx < detents.count {
        sheet.largestUndimmedDetentIdentifier = detents[undimmedIdx].identifier(at: undimmedIdx)
    }
    if #available(iOS 17, *) {
        sheet.prefersPageSizing = prefersPageSz
    }

    // iOS uses system dimming (no public scrimColor/alpha API).
    // Scrim customization is Android-only by design (option A); use
    // `largestUndimmedDetentIdentifier` (via largestUndimmedDetent) to
    // control *whether* dimming appears.
    // TODO: custom scrimOpacity via UIPresentationController subclass.
    _ = scrimOpacity  // acknowledged; full implementation in P2

    // ── Delegate ─────────────────────────────────────────────────────
    let delegate = _SheetDelegate(
        sheetId: sheetId,
        detents: detents,
        isDismissable: isDismissable
    )
    sheet.delegate = delegate
    presentedVC.presentationController?.delegate = delegate
    _delegates[sheetId] = delegate  // retain

    // ── Register entry synchronously so layout passes and FFI find it immediately ──
    let entry = _SheetEntry(
        sheetId: sheetId,
        rootViewId: rootViewId,
        presentingVC: presenter,
        containerVC: containerVC,
        navController: navController,
        detents: detents
    )
    _activeSheets[sheetId] = entry

    // Present asynchronously so Dart's attachRoot executes synchronously before presentation begins
    DispatchQueue.main.async {
        presenter.present(presentedVC, animated: true) {
            containerVC.layoutRootFlex()
            fireToDart(token: sheetId, type: kEventPresented, payload: "{}")
        }
    }

    return rootViewId
}

/// Mount Dart content (identified by viewId) into the open sheet's container.
@_cdecl("DNBottomSheetMountContent")
public func DNBottomSheetMountContent(_ sheetId: Int64, _ viewId: Int64) {
    DispatchQueue.main.async {
        guard let entry = _activeSheets[sheetId] else { return }
        guard let dartView = _viewFor(viewId) else {
            dnLog("DNBottomSheetMountContent: viewId \(viewId) not found")
            return
        }
        let container = entry.containerVC.view!
        // Remove any previously mounted view.
        container.subviews.forEach { $0.removeFromSuperview() }
        entry.containerVC.rootView = dartView
        container.addSubview(dartView)
        entry.containerVC.layoutRootFlex()
    }
}

/// Request an explicit FlexLayout pass on the sheet's root view.
@_cdecl("DNBottomSheetLayoutContent")
public func DNBottomSheetLayoutContent(_ sheetId: Int64) {
    DispatchQueue.main.async {
        guard let entry = _activeSheets[sheetId] else { return }
        entry.containerVC.layoutRootFlex()
        if #available(iOS 16, *) {
            let sheet = entry.containerVC.sheetPresentationController
                ?? entry.navController?.sheetPresentationController
            sheet?.animateChanges {
                sheet?.invalidateDetents()
            }
        }
    }
}

/// Dismiss a sheet programmatically.
@_cdecl("DNBottomSheetDismiss")
public func DNBottomSheetDismiss(_ sheetId: Int64, _ animated: Bool) {
    DispatchQueue.main.async {
        guard let entry = _activeSheets[sheetId], !entry.isDismissing else { return }
        entry.isDismissing = true
        entry.containerVC.dismiss(animated: animated) {
            if let e = _activeSheets.removeValue(forKey: sheetId) {
                _dnDisposeView?(e.rootViewId)
            }
            _delegates.removeValue(forKey: sheetId)
            fireToDart(token: sheetId, type: kEventDismissed, payload: "{}")
        }
    }
}

/// Snap to a detent by index.
@_cdecl("DNBottomSheetSnapTo")
public func DNBottomSheetSnapTo(_ sheetId: Int64, _ detentIndex: Int32, _ animated: Bool) {
    guard #available(iOS 15, *) else { return }
    DispatchQueue.main.async {
        guard let entry = _activeSheets[sheetId] else { return }
        let idx = Int(detentIndex)
        guard idx >= 0 && idx < entry.detents.count else { return }
        let identifier = entry.detents[idx].identifier(at: idx)
        guard let sheet = entry.containerVC.sheetPresentationController
            ?? entry.navController?.sheetPresentationController
        else { return }
        if animated {
            sheet.animateChanges { sheet.selectedDetentIdentifier = identifier }
        } else {
            sheet.selectedDetentIdentifier = identifier
        }
    }
}

/// Re-evaluate custom (contentFit / fraction / pixels) detent resolvers.
/// iOS 16+ only; no-op on iOS 15.
@_cdecl("DNBottomSheetInvalidateDetents")
public func DNBottomSheetInvalidateDetents(_ sheetId: Int64) {
    guard #available(iOS 16, *) else { return }
    DispatchQueue.main.async {
        guard let entry = _activeSheets[sheetId] else { return }
        let sheet = entry.containerVC.sheetPresentationController
            ?? entry.navController?.sheetPresentationController
        sheet?.animateChanges { sheet?.invalidateDetents() }
    }
}

/// Begin a coordinated animation transaction (animateChanges open).
@_cdecl("DNBottomSheetAnimateChangesBegin")
public func DNBottomSheetAnimateChangesBegin(_ sheetId: Int64) {
    // On iOS we batch by opening a CATransaction; the actual sheet.animateChanges{}
    // wraps the entire begin→end block on the native side.
    // For simplicity: this is a no-op — SnapTo / InvalidateDetents each wrap
    // their own animateChanges. A full transaction grouping would require a
    // deferred execution queue; that is a P2 refinement.
    _ = sheetId
}

/// End a coordinated animation transaction (animateChanges close).
@_cdecl("DNBottomSheetAnimateChangesEnd")
public func DNBottomSheetAnimateChangesEnd(_ sheetId: Int64) {
    _ = sheetId  // see above
}

/// Push a new page onto the sheet's internal navigation stack.
@_cdecl("DNBottomSheetPush")
public func DNBottomSheetPush(_ sheetId: Int64, _ expandsToDetentIndex: Int32) {
    guard #available(iOS 15, *) else { return }
    DispatchQueue.main.async {
        guard let entry = _activeSheets[sheetId],
              let nav = entry.navController
        else { return }

        let pageVC = UIViewController()
        pageVC.view.backgroundColor = .clear
        nav.pushViewController(pageVC, animated: true)

        // Optionally snap to a larger detent on push.
        let idx = Int(expandsToDetentIndex)
        if idx >= 0 && idx < entry.detents.count,
           let sheet = nav.sheetPresentationController {
            let id = entry.detents[idx].identifier(at: idx)
            sheet.animateChanges { sheet.selectedDetentIdentifier = id }
        }
    }
}

/// Pop the top page from the sheet's navigation stack.
@_cdecl("DNBottomSheetPop")
public func DNBottomSheetPop(_ sheetId: Int64) {
    DispatchQueue.main.async {
        guard let entry = _activeSheets[sheetId],
              let nav = entry.navController
        else { return }
        nav.popViewController(animated: true)
    }
}
