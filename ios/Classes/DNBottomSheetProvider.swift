import UIKit
import FlexLayout

private func dnLog(_ msg: String) { print("[DNBottomSheet] \(msg)") }

// ─── UIColor Utilities ───────────────────────────────────────────────────────

private extension UIColor {
    /// Consolidated interface style calculation via relative luminance (0.2126R + 0.7152G + 0.0722B).
    var dnInterfaceStyle: UIUserInterfaceStyle {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            guard a > 0.05 else { return .unspecified }
            let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            return lum < 0.5 ? .dark : .light
        }
        var white: CGFloat = 0
        if getWhite(&white, alpha: &a) {
            guard a > 0.05 else { return .unspecified }
            return white < 0.5 ? .dark : .light
        }
        if let converted = cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
           let comps = converted.components, comps.count >= 3 {
            let alpha = converted.alpha
            guard alpha > 0.05 else { return .unspecified }
            let lum = 0.2126 * comps[0] + 0.7152 * comps[1] + 0.0722 * comps[2]
            return lum < 0.5 ? .dark : .light
        }
        return .unspecified
    }
}

// ─── First-View Traversal Helpers ───────────────────────────────────────────

private func viewBackgroundColor(_ v: UIView) -> UIColor? {
    if let bg = v.backgroundColor, bg != .clear, bg.cgColor.alpha > 0.05 {
        return bg
    }
    if let layerBg = v.layer.backgroundColor {
        let col = UIColor(cgColor: layerBg)
        if col != .clear && col.cgColor.alpha > 0.05 {
            return col
        }
    }
    return nil
}

/// Restricts background search to the first view branch (root view and its immediate first child/spine)
/// instead of checking the whole tree.
private func findFirstViewBackground(in root: UIView?) -> UIColor? {
    guard let root = root else { return nil }
    if let bg = viewBackgroundColor(root) {
        return bg
    }
    var current: UIView? = root.subviews.first
    while let v = current {
        if let bg = viewBackgroundColor(v) {
            return bg
        }
        current = v.subviews.first
    }
    return nil
}

/// Finds the first UIScrollView using shallow breadth-first traversal, stopping immediately on the first match.
private func findFirstScrollView(in root: UIView?) -> UIScrollView? {
    guard let root = root else { return nil }
    var queue: [UIView] = [root]
    while !queue.isEmpty {
        let current = queue.removeFirst()
        if let sv = current as? UIScrollView {
            return sv
        }
        queue.append(contentsOf: current.subviews)
    }
    return nil
}

// ─── Container View Controller with FlexLayout ──────────────────────────────

private final class _DNBottomSheetContainerViewController: UIViewController {
    weak var rootView: UIView?
    /// Explicit sheet background. When set, it wins and the child-bg scan is skipped.
    var explicitBackgroundColor: UIColor?
    /// When false (and no explicit color), keep the platform default instead of scanning.
    var adaptToContainerBackground = true

    // Cached appearances
    private var lastBackgroundColor: UIColor?
    private var lastInterfaceStyle: UIUserInterfaceStyle?

    // Cached scroll view
    private weak var cachedScrollView: UIScrollView?
    private var didResolveScrollView = false

    // Cached content height measurement
    private var cachedContentHeight: CGFloat?
    private var cachedMeasurementWidth: CGFloat?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let explicit = explicitBackgroundColor {
            applyEffectiveBackgroundColor(explicit)
        } else if adaptToContainerBackground {
            view.backgroundColor = .clear
        } else {
            applyEffectiveBackgroundColor(.systemBackground)
        }
        view.clipsToBounds = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        layoutRootFlex()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        layoutRootFlex()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutRootFlex()
    }

    func resetScrollViewCache() {
        cachedScrollView = nil
        didResolveScrollView = false
    }

    private func resolveScrollViewIfNeeded() {
        guard !didResolveScrollView else { return }
        didResolveScrollView = true
        cachedScrollView = findFirstScrollView(in: rootView)
    }

    @available(iOS 15.0, *)
    override func contentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView? {
        if edge == .top {
            resolveScrollViewIfNeeded()
            return cachedScrollView
        }
        return super.contentScrollView(for: edge)
    }

    func applyEffectiveBackgroundColor(_ bg: UIColor) {
        let style = bg.dnInterfaceStyle
        guard lastBackgroundColor != bg || lastInterfaceStyle != style else { return }
        lastBackgroundColor = bg
        lastInterfaceStyle = style

        view.backgroundColor = bg
        navigationController?.view.backgroundColor = bg

        overrideUserInterfaceStyle = style
        navigationController?.overrideUserInterfaceStyle = style
        presentationController?.containerView?.overrideUserInterfaceStyle = style
        presentationController?.presentedView?.overrideUserInterfaceStyle = style
        navigationController?.presentationController?.containerView?.overrideUserInterfaceStyle = style
        navigationController?.presentationController?.presentedView?.overrideUserInterfaceStyle = style
    }

    func syncBackgroundColor() {
        // Explicit color always wins — re-enforce it.
        if let explicit = explicitBackgroundColor {
            applyEffectiveBackgroundColor(explicit)
            return
        }
        // Opted out of child-bg scan: keep platform default.
        if !adaptToContainerBackground { return }

        // Restrict background searching to the first view instead of checking the whole tree.
        if let bg = findFirstViewBackground(in: rootView) {
            applyEffectiveBackgroundColor(bg)
        }
    }

    func invalidateContentHeightCache() {
        cachedContentHeight = nil
        cachedMeasurementWidth = nil
    }

    func measureContentHeight(forWidth width: CGFloat) -> CGFloat {
        if let cachedW = cachedMeasurementWidth, cachedW == width,
           let cachedH = cachedContentHeight {
            return cachedH
        }

        guard let rv = rootView else { return 0 }
        let targetWidth = width > 0 ? width : (view.bounds.width > 0 ? view.bounds.width : (view.window?.bounds.width ?? 390))
        rv.frame = CGRect(x: 0, y: 0, width: targetWidth, height: 0)
        rv.flex.layout(mode: .adjustHeight)
        let measured = rv.frame.height
        if view.bounds.height > 0 {
            rv.frame = view.bounds
            rv.flex.layout(mode: .fitContainer)
        }

        cachedMeasurementWidth = width
        cachedContentHeight = measured
        return measured
    }

    func layoutRootFlex() {
        guard let rv = rootView else { return }
        rv.frame = view.bounds
        rv.flex.layout(mode: .fitContainer)
        _dnCATransactionCommit?()
    }
}

// ─── Dispatcher Slot ────────────────────────────────────────────────────────

private let _dispatcherSlot: UnsafeMutablePointer<Int64> = {
    let p = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
    p.pointee = 0
    return p
}()
private var _slotRegistered = false

private typealias _DispatchFn = @convention(c) (Int64, Int32, UnsafePointer<CChar>) -> Void

private func fireToDart(token: Int64, type: Int32, payload: String) {
    assert(Thread.isMainThread, "fireToDart must be called on the main thread")
    let addr = _dispatcherSlot.pointee   // read FRESH every time
    guard addr != 0 else { return }      // hot restart happened → drop quietly
    payload.withCString { cStr in
        unsafeBitCast(addr, to: _DispatchFn.self)(token, type, cStr)
    }
}

// ─── Event Constants (must match ffi_bindings.dart) ─────────────────────────

private let kEventDetentChanged:    Int32 = 1
private let kEventDismissed:        Int32 = 2
private let kEventDismissAttempted: Int32 = 3
private let kEventPresented:        Int32 = 4

// ─── Detent Specifications ──────────────────────────────────────────────────

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
                    let targetWidth = sheetWidth > 0 ? sheetWidth : ctx.maximumDetentValue
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
            let halfScreen = (contentVC?.view.window?.bounds.height ?? 800) / 2
            return h < halfScreen ? .medium() : .large()
        default:
            return .large()
        }
    }
}

@available(iOS 15, *)
private struct ResolvedDetent {
    let spec: _DetentSpec
    let identifier: UISheetPresentationController.Detent.Identifier
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

// ─── Sheet Entry ────────────────────────────────────────────────────────────

@available(iOS 15, *)
private final class _SheetEntry {
    let sheetId: Int64
    let rootViewId: Int64
    let presentingVC: UIViewController
    let containerVC: _DNBottomSheetContainerViewController
    let navController: UINavigationController?
    let detents: [ResolvedDetent]
    var delegate: AnyObject?
    var isDismissing = false
    var hasPresented = false

    var presentedVC: UIViewController {
        navController ?? containerVC
    }

    init(
        sheetId: Int64,
        rootViewId: Int64,
        presentingVC: UIViewController,
        containerVC: _DNBottomSheetContainerViewController,
        navController: UINavigationController?,
        detents: [ResolvedDetent]
    ) {
        self.sheetId = sheetId
        self.rootViewId = rootViewId
        self.presentingVC = presentingVC
        self.containerVC = containerVC
        self.navController = navController
        self.detents = detents
    }

    func presentIfNeeded() {
        guard !hasPresented else { return }
        hasPresented = true

        containerVC.layoutRootFlex()
        containerVC.syncBackgroundColor()

        let pVC = presentedVC
        if let bg = containerVC.view.backgroundColor, bg != .clear {
            pVC.view.backgroundColor = bg
            let style = bg.dnInterfaceStyle
            pVC.overrideUserInterfaceStyle = style
            containerVC.overrideUserInterfaceStyle = style
            pVC.presentationController?.containerView?.overrideUserInterfaceStyle = style
            pVC.presentationController?.presentedView?.overrideUserInterfaceStyle = style
        }

        presentingVC.present(pVC, animated: true) { [weak self] in
            guard let self = self else { return }
            self.containerVC.layoutRootFlex()
            fireToDart(token: self.sheetId, type: kEventPresented, payload: "{}")
        }

        if let tc = pVC.transitionCoordinator {
            tc.animate(alongsideTransition: { [weak self] ctx in
                if let bg = self?.containerVC.view.backgroundColor, bg != .clear {
                    let style = bg.dnInterfaceStyle
                    ctx.containerView.overrideUserInterfaceStyle = style
                }
            }, completion: nil)
        }
    }
}

// ─── Bottom Sheet Manager ───────────────────────────────────────────────────

@available(iOS 15, *)
private final class _DNBottomSheetManager {
    static let shared = _DNBottomSheetManager()

    private var sheets: [Int64: _SheetEntry] = [:]

    func register(_ entry: _SheetEntry) {
        assert(Thread.isMainThread, "register must run on the main thread")
        sheets[entry.sheetId] = entry
    }

    func entry(for sheetId: Int64) -> _SheetEntry? {
        assert(Thread.isMainThread, "entry must run on the main thread")
        return sheets[sheetId]
    }

    func cleanupSheet(_ sheetId: Int64, notify: Bool) {
        assert(Thread.isMainThread, "cleanupSheet must run on the main thread")
        guard let entry = sheets.removeValue(forKey: sheetId) else { return }
        _dnDisposeView?(entry.rootViewId)
        if notify {
            fireToDart(token: sheetId, type: kEventDismissed, payload: "{}")
        }
    }

    func resetOnHotRestart() {
        assert(Thread.isMainThread, "resetOnHotRestart must run on the main thread")
        guard !sheets.isEmpty else { return }
        let allSheets = Array(sheets.values)
        sheets.removeAll()
        for entry in allSheets {
            _dnDisposeView?(entry.rootViewId)
            entry.containerVC.dismiss(animated: false, completion: nil)
        }
    }
}

// ─── Sheet Delegate ─────────────────────────────────────────────────────────

@available(iOS 15, *)
private final class _SheetDelegate: NSObject,
    UISheetPresentationControllerDelegate,
    UIAdaptivePresentationControllerDelegate
{
    let sheetId: Int64
    let detents: [ResolvedDetent]
    var isDismissable: Bool

    init(sheetId: Int64, detents: [ResolvedDetent], isDismissable: Bool) {
        self.sheetId = sheetId
        self.detents = detents
        self.isDismissable = isDismissable
    }

    // Detent changed
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheet: UISheetPresentationController
    ) {
        guard let id = sheet.selectedDetentIdentifier else { return }
        let idx = detents.indices.first {
            detents[$0].identifier == id
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
        _DNBottomSheetManager.shared.cleanupSheet(sheetId, notify: true)
    }
}

// ─── JSON Parsing Helper ────────────────────────────────────────────────────

private func parseJSON(_ cStr: UnsafePointer<CChar>) -> [String: Any]? {
    guard let data = String(cString: cStr).data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return obj
}

// ─── DNViewRegistry Dynamic Symbol Resolution ───────────────────────────────

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

// ── Find Front-most Presenting VC ───────────────────────────────────────────

private func frontVC() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes
        .filter({ $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
        .compactMap({ $0 as? UIWindowScene })
        .first ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
    else { return nil }

    guard let root = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
        ?? windowScene.windows.first?.rootViewController
    else { return nil }

    var vc: UIViewController = root
    while let p = vc.presentedViewController, !p.isBeingDismissed {
        vc = p
    }
    return vc
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - @_cdecl Exports
// ─────────────────────────────────────────────────────────────────────────────

/// Called once by Dart's loadSymbols(). Re-called on hot restart with the new
/// session's dispatcher pointer — we use this to dismiss any zombie sheets.
@_cdecl("DNBottomSheetSetDispatcher")
public func DNBottomSheetSetDispatcher(_ callbackPtr: Int64) {
    if #available(iOS 15, *) {
        if Thread.isMainThread {
            _DNBottomSheetManager.shared.resetOnHotRestart()
        } else {
            DispatchQueue.main.async {
                _DNBottomSheetManager.shared.resetOnHotRestart()
            }
        }
    }

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

    // Pre-resolve detents and their identifiers
    let detents: [ResolvedDetent] = detentDicts.enumerated().map { (idx, dict) in
        let spec = parseDetent(from: dict)
        let id: UISheetPresentationController.Detent.Identifier
        switch spec {
        case .named(let n) where n == "medium": id = .medium
        case .named(let n) where n == "large":  id = .large
        default:
            id = UISheetPresentationController.Detent.Identifier("dn.custom.\(idx)")
        }
        return ResolvedDetent(spec: spec, identifier: id)
    }

    guard let presenter = frontVC() else {
        dnLog("DNBottomSheetShow: could not find front VC")
        return 0
    }

    // Allocate root DNView for Dart content
    let rootViewId = _dnCreateView?(0) ?? 0
    let dartRootView = _viewFor(rootViewId)

    // Pre-calculate target bounds from presenter/window
    let screenBounds = presenter.view.window?.bounds ?? presenter.view.bounds
    let targetWidth = screenBounds.width > 0 ? screenBounds.width : 390
    let targetHeight: CGFloat
    if let firstDetent = detents.first {
        switch firstDetent.spec {
        case .named(let n) where n == "medium":
            targetHeight = (screenBounds.height > 0 ? screenBounds.height : 844) * 0.5
        case .named(let n) where n == "large":
            targetHeight = (screenBounds.height > 0 ? screenBounds.height : 844) * 0.9
        case .fraction(let f):
            targetHeight = (screenBounds.height > 0 ? screenBounds.height : 844) * CGFloat(f)
        case .pixels(let p):
            targetHeight = CGFloat(p)
        default:
            targetHeight = (screenBounds.height > 0 ? screenBounds.height : 844) * 0.5
        }
    } else {
        targetHeight = (screenBounds.height > 0 ? screenBounds.height : 844) * 0.5
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

    if let explicit = explicitBg {
        containerVC.applyEffectiveBackgroundColor(explicit)
        presentedVC.view.backgroundColor = explicit
        presentedVC.overrideUserInterfaceStyle = explicit.dnInterfaceStyle
    }

    guard let sheet = presentedVC.sheetPresentationController else {
        dnLog("DNBottomSheetShow: no sheetPresentationController")
        return rootViewId
    }

    // ── Detents ──────────────────────────────────────────────────────
    sheet.detents = detents.map { resolved in
        resolved.spec.uiDetent(
            identifier: resolved.identifier,
            contentVC: containerVC
        )
    }
    if initIdx < detents.count {
        sheet.selectedDetentIdentifier = detents[initIdx].identifier
    }

    // ── Appearance ───────────────────────────────────────────────────
    sheet.prefersGrabberVisible             = showGrabber
    sheet.preferredCornerRadius             = cornerRadius
    sheet.prefersScrollingExpandsWhenScrolledToEdge = scrollExpands
    sheet.prefersEdgeAttachedInCompactHeight = edgeAttached
    sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = widthFollows

    if undimmedIdx >= 0 && undimmedIdx < detents.count {
        sheet.largestUndimmedDetentIdentifier = detents[undimmedIdx].identifier
    }
    if #available(iOS 17, *) {
        sheet.prefersPageSizing = prefersPageSz
    }

    _ = scrimOpacity

    // ── Delegate ─────────────────────────────────────────────────────
    let delegate = _SheetDelegate(
        sheetId: sheetId,
        detents: detents,
        isDismissable: isDismissable
    )
    sheet.delegate = delegate
    presentedVC.presentationController?.delegate = delegate

    // ── Register entry in manager ────────────────────────────────────
    let entry = _SheetEntry(
        sheetId: sheetId,
        rootViewId: rootViewId,
        presentingVC: presenter,
        containerVC: containerVC,
        navController: navController,
        detents: detents
    )
    entry.delegate = delegate

    if Thread.isMainThread {
        _DNBottomSheetManager.shared.register(entry)
    } else {
        DispatchQueue.main.sync {
            _DNBottomSheetManager.shared.register(entry)
        }
    }

    // Present on the next runloop turn; content mounting happens synchronously on the Dart side.
    DispatchQueue.main.async {
        entry.presentIfNeeded()
    }

    return rootViewId
}

/// Mount Dart content (identified by viewId) into the open sheet's container.
@_cdecl("DNBottomSheetMountContent")
public func DNBottomSheetMountContent(_ sheetId: Int64, _ viewId: Int64) {
    guard #available(iOS 15, *) else { return }
    DispatchQueue.main.async {
        guard let entry = _DNBottomSheetManager.shared.entry(for: sheetId) else { return }
        guard let dartView = _viewFor(viewId) else {
            dnLog("DNBottomSheetMountContent: viewId \(viewId) not found")
            return
        }
        let container = entry.containerVC.view!
        container.subviews.forEach { $0.removeFromSuperview() }
        entry.containerVC.rootView = dartView
        entry.containerVC.resetScrollViewCache()
        entry.containerVC.invalidateContentHeightCache()
        container.addSubview(dartView)
        entry.containerVC.layoutRootFlex()
        entry.containerVC.syncBackgroundColor()
    }
}

/// Request an explicit FlexLayout pass on the sheet's root view.
@_cdecl("DNBottomSheetLayoutContent")
public func DNBottomSheetLayoutContent(_ sheetId: Int64) {
    guard #available(iOS 15, *) else { return }
    DispatchQueue.main.async {
        guard let entry = _DNBottomSheetManager.shared.entry(for: sheetId) else { return }
        entry.containerVC.invalidateContentHeightCache()
        entry.containerVC.layoutRootFlex()
        entry.presentIfNeeded()
        if #available(iOS 16, *) {
            let hasContentFit = entry.detents.contains { resolved in
                if case .named(let n) = resolved.spec, n == "contentFit" { return true }
                return false
            }
            if hasContentFit {
                let sheet = entry.containerVC.sheetPresentationController
                    ?? entry.navController?.sheetPresentationController
                sheet?.animateChanges {
                    sheet?.invalidateDetents()
                }
            }
        }
    }
}

/// Dismiss a sheet programmatically.
@_cdecl("DNBottomSheetDismiss")
public func DNBottomSheetDismiss(_ sheetId: Int64, _ animated: Bool) {
    guard #available(iOS 15, *) else { return }
    DispatchQueue.main.async {
        guard let entry = _DNBottomSheetManager.shared.entry(for: sheetId), !entry.isDismissing else { return }
        entry.isDismissing = true
        entry.containerVC.dismiss(animated: animated) {
            _DNBottomSheetManager.shared.cleanupSheet(sheetId, notify: true)
        }
    }
}

/// Snap to a detent by index.
@_cdecl("DNBottomSheetSnapTo")
public func DNBottomSheetSnapTo(_ sheetId: Int64, _ detentIndex: Int32, _ animated: Bool) {
    guard #available(iOS 15, *) else { return }
    DispatchQueue.main.async {
        guard let entry = _DNBottomSheetManager.shared.entry(for: sheetId) else { return }
        let idx = Int(detentIndex)
        guard idx >= 0 && idx < entry.detents.count else { return }
        let identifier = entry.detents[idx].identifier
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
        guard let entry = _DNBottomSheetManager.shared.entry(for: sheetId) else { return }
        entry.containerVC.invalidateContentHeightCache()
        let sheet = entry.containerVC.sheetPresentationController
            ?? entry.navController?.sheetPresentationController
        sheet?.animateChanges { sheet?.invalidateDetents() }
    }
}

/// Begin a coordinated animation transaction.
@_cdecl("DNBottomSheetAnimateChangesBegin")
public func DNBottomSheetAnimateChangesBegin(_ sheetId: Int64) {
    _ = sheetId
}

/// End a coordinated animation transaction.
@_cdecl("DNBottomSheetAnimateChangesEnd")
public func DNBottomSheetAnimateChangesEnd(_ sheetId: Int64) {
    _ = sheetId
}

/// Push a new page onto the sheet's internal navigation stack.
@_cdecl("DNBottomSheetPush")
public func DNBottomSheetPush(_ sheetId: Int64, _ expandsToDetentIndex: Int32) {
    guard #available(iOS 15, *) else { return }
    DispatchQueue.main.async {
        guard let entry = _DNBottomSheetManager.shared.entry(for: sheetId) else { return }

        // Perform a native slide-in push animation on the container view without
        // displacing or hiding the Dart root view with a blank UIViewController.
        let transition = CATransition()
        transition.duration = 0.28
        transition.type = .push
        transition.subtype = .fromRight
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        entry.containerVC.view.layer.add(transition, forKey: kCATransition)
        entry.containerVC.layoutRootFlex()

        let idx = Int(expandsToDetentIndex)
        if idx >= 0 && idx < entry.detents.count,
           let sheet = entry.containerVC.sheetPresentationController ?? entry.navController?.sheetPresentationController {
            let id = entry.detents[idx].identifier
            sheet.animateChanges { sheet.selectedDetentIdentifier = id }
        }
    }
}

/// Pop the top page from the sheet's navigation stack.
@_cdecl("DNBottomSheetPop")
public func DNBottomSheetPop(_ sheetId: Int64) {
    guard #available(iOS 15, *) else { return }
    DispatchQueue.main.async {
        guard let entry = _DNBottomSheetManager.shared.entry(for: sheetId) else { return }

        let transition = CATransition()
        transition.duration = 0.28
        transition.type = .push
        transition.subtype = .fromLeft
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        entry.containerVC.view.layer.add(transition, forKey: kCATransition)
        entry.containerVC.layoutRootFlex()
    }
}

