import 'package:dartnative/dartnative.dart';
import 'package:dartnative/flutter_compat.dart';
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';
import 'package:example/component/adjust_detent_sheet.dart';
import 'package:example/component/fit_content_sheet.dart';
import 'package:example/component/input_sheet.dart';
import 'package:example/component/prevent_close_sheet.dart';
import 'package:example/component/scrollable_sheet.dart';
import 'package:example/component/stacked_sheet.dart';

import 'dartnative_plugin_registrant.dart';

void main() {
  DartNativePluginRegistrant.registerAll();

  SystemChrome.defaultStyle = const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  DartNativeLogger.run(
    () {
      runApp(const BottomSheetExampleApp());
    },
    verbose: true, // framework-internal diagnostics
    saveToFile: true, // persist every session to a log file
  );
  // runApp(const BottomSheetExampleApp());
}

class BottomSheetExampleApp extends StatefulWidget {
  const BottomSheetExampleApp({super.key});

  @override
  State<BottomSheetExampleApp> createState() => _BottomSheetExampleAppState();
}

class _BottomSheetExampleAppState extends State<BottomSheetExampleApp> {
  String _lastEvent = 'Ready to test bottom sheets';
  int _attemptCount = 0;
  DNSheetController? _currentActiveSheet;

  void _updateStatus(String message) {
    _lastEvent = message;
    // ignore: avoid_print
    print('[BottomSheetExample] $_lastEvent (activeSheet: ${_currentActiveSheet != null})');
  }

  // ── 1. Fit to Content ───────────────────────────────────────────────────────
  void _openFitToContentSheet() {
    _updateStatus('Opening Fit-to-Content sheet...');
    _currentActiveSheet = showBottomSheet(
      context,
      detents: const [DNSheetDetent.contentFit],
      initialDetent: DNSheetDetent.contentFit,
      showGrabber: true,
      platformConfig: DNSheetPlatformConfig.android(),
      builder: (ctx, ctrl) => FitContentSheet(
        controller: ctrl,
        onStateChanged: (desc) => _updateStatus('Fit Content: $desc'),
      ),
      onDetentChanged: (d) =>
          _updateStatus('Fit Content settled at: ${d.label}'),
      onDismissed: () {
        _updateStatus('Fit Content sheet dismissed');
        setState(() => _currentActiveSheet = null);
      },
    );
  }

  // ── 2. Bottomsheet with Input ──────────────────────────────────────────────
  void _openInputSheet() {
    _updateStatus('Opening Sheet with Input...');
    _currentActiveSheet = showBottomSheet(
      context,
      detents: const [DNSheetDetent.medium, DNSheetDetent.large],
      initialDetent: DNSheetDetent.medium,
      showGrabber: true,
      builder: (ctx, ctrl) => InputSheet(
        controller: ctrl,
        onSubmit: (text) => _updateStatus('Input submitted: "$text"'),
      ),
      platformConfig: DNSheetPlatformConfig.ios(),
      onDetentChanged: (d) => _updateStatus('Input sheet detent: ${d.label}'),
      onDismissed: () {
        _updateStatus('Input sheet dismissed');
        setState(() => _currentActiveSheet = null);
      },
    );
  }

  // ── 3. General with Adjust Detent ──────────────────────────────────────────
  void _openAdjustDetentSheet() {
    _updateStatus('Opening Adjust Detent sheet...');
    _currentActiveSheet = showBottomSheet(
      context,
      detents: const [
        DNSheetDetent.fraction(0.35),
        DNSheetDetent.medium,
        DNSheetDetent.large,
      ],
      initialDetent: DNSheetDetent.fraction(0.35),
      showGrabber: true,
      builder: (ctx, ctrl) => AdjustDetentSheet(
        controller: ctrl,
        onSnapRequested: (label) =>
            _updateStatus('Programmatic snap to: $label'),
      ),
      onDetentChanged: (d) => _updateStatus('Detent changed to: ${d.label}'),
      onDismissed: () {
        _updateStatus('Adjust Detent sheet dismissed');
        setState(() => _currentActiveSheet = null);
      },
    );
  }

  // ── 4. Prevent Close (Non-dismissable) ──────────────────────────────────────
  void _openPreventCloseSheet() {
    _attemptCount = 0;
    _updateStatus('Opening Prevent-Close sheet (drag/scrim blocked)...');
    _currentActiveSheet = showBottomSheet(
      context,
      detents: const [DNSheetDetent.medium],
      initialDetent: DNSheetDetent.medium,
      isDismissable: false,
      showGrabber: true,
      builder: (ctx, ctrl) => PreventCloseSheet(
        controller: ctrl,
        attemptCount: _attemptCount,
        onExplicitClose: () {
          _updateStatus('Prevent-Close sheet dismissed explicitly via button');
          ctrl.dismiss();
        },
      ),
      onDismissAttempted: () {
        setState(() {
          _attemptCount++;
        });
        _updateStatus(
          'Dismiss attempted ($_attemptCount times)! Blocked natively.',
        );
      },
      onDismissed: () {
        _updateStatus('Prevent-Close sheet closed');
        setState(() => _currentActiveSheet = null);
      },
    );
  }

  // ── 5. Scrollable Content ────────────────────────────────────────────────
  void _openScrollableSheet() {
    _updateStatus('Opening Scrollable sheet...');
    _currentActiveSheet = showBottomSheet(
      context,
      detents: const [DNSheetDetent.medium, DNSheetDetent.large],
      initialDetent: DNSheetDetent.medium,
      showGrabber: true,
      platformConfig: DNSheetPlatformConfig(
        android: DNSheetAndroidConfig(),
        ios: DNSheetIOSConfig(edgeAttachedInCompactHeight: true),
      ),
      scrollExpandsSheet: true,
      builder: (ctx, ctrl) => ScrollableSheet(
        controller: ctrl,
        onSnapRequested: (label) =>
            _updateStatus('Programmatic snap to: $label'),
      ),
      onDetentChanged: (d) => _updateStatus('Scrollable detent: ${d.label}'),
      onDismissed: () {
        _updateStatus('Scrollable sheet dismissed');
        setState(() => _currentActiveSheet = null);
      },
    );
  }

  // ── 6. Stacked Sheet ───────────────────────────────────────────────────────
  void _openStackedSheet() {
    _updateStatus('Opening Stacked sheet...');
    _currentActiveSheet = showBottomSheet(
      context,
      detents: const [DNSheetDetent.medium, DNSheetDetent.large],
      initialDetent: DNSheetDetent.medium,
      showGrabber: true,
      builder: (ctx, ctrl) => StackedSheet(controller: ctrl, level: 1),
      onDetentChanged: (d) => _updateStatus('Stacked sheet detent: ${d.label}'),
      onDismissed: () {
        _updateStatus('Stacked sheet dismissed');
        setState(() => _currentActiveSheet = null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      brightness: Brightness.light,
      appBar: AppBar(
        title: const Text(
          'BottomSheet Examples',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Section 1: Fit Content
          TestCaseCard(
            title: 'Fit to Content',
            description:
                'Auto-measures intrinsic content height using Yoga. Dynamically expands or collapses size on state mutation.',
            buttonText: 'Test Fit to Content',
            buttonColor: const Color(0xFF34C759),
            onTap: _openFitToContentSheet,
          ),
          const SizedBox(height: 14),

          // Section 2: Input Sheet
          TestCaseCard(
            title: 'Sheet with Input',
            description:
                'Embedded native TextField with keyboard elevation, focus handling, live text mirroring, and form submission.',
            buttonText: 'Test Input Sheet',
            buttonColor: const Color(0xFF007AFF),
            onTap: _openInputSheet,
          ),
          const SizedBox(height: 14),

          // Section 3: General with Adjust Detents
          TestCaseCard(
            title: 'Adjust Detents',
            description:
                'Multi-detent support (fraction 35%, medium 50%, large 100%). Interactive buttons to snap between detents programmatically.',
            buttonText: 'Test Adjust Detents',
            buttonColor: const Color(0xFF5856D6),
            onTap: _openAdjustDetentSheet,
          ),
          const SizedBox(height: 14),

          // Section 4: Prevent Close
          TestCaseCard(
            title: 'Prevent Close',
            description:
                'Blocks swipe-to-dismiss and scrim taps. Calls onDismissAttempted callback; requires explicit confirmation button to close.',
            buttonText: 'Test Prevent Close',
            buttonColor: const Color(0xFFFF9500),
            onTap: _openPreventCloseSheet,
          ),
          const SizedBox(height: 14),

          // Section 5: Scrollable Content
          TestCaseCard(
            title: 'Scrollable Content',
            description:
                '60 rows in a fixed-height list. Scroll inside the sheet, snap between medium/large, and test scroll-expands-sheet at the list edge.',
            buttonText: 'Test Scrollable Sheet',
            buttonColor: const Color(0xFF30B0C7),
            onTap: _openScrollableSheet,
          ),
          const SizedBox(height: 14),

          // Section 6: Stacked Sheet
          TestCaseCard(
            title: 'Stacked Sheet',
            description:
                'Open a bottom sheet from within another bottom sheet to test stacked rendering and gesture resolution.',
            buttonText: 'Test Stacked Sheet',
            buttonColor: const Color(0xFFFF6B35),
            onTap: _openStackedSheet,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test Case Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class TestCaseCard extends StatelessWidget {
  const TestCaseCard({
    required this.title,
    required this.description,
    required this.buttonText,
    required this.buttonColor,
    required this.onTap,
  });

  final String title;
  final String description;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Button(title: title, child: Text(description), onPressed: onTap),
      ],
    );
  }
}

class SnapButton extends StatelessWidget {
  const SnapButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF5856D6).withOpacity(0.25)
              : const Color(0xFF242426),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF5856D6) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: isSelected ? const Color(0xFF5856D6) : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
