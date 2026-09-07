import 'package:dartnative/dartnative.dart';
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';
import 'package:example/main.dart';

class AdjustDetentSheet extends StatefulWidget {
  const AdjustDetentSheet({
    required this.controller,
    required this.onSnapRequested,
  });

  final DNSheetController controller;
  final void Function(String label) onSnapRequested;

  @override
  State<AdjustDetentSheet> createState() => AdjustDetentSheetState();
}

class AdjustDetentSheetState extends State<AdjustDetentSheet> {
  DNSheetDetent _activeDetent = const DNSheetDetent.fraction(0.35);

  void _snap(DNSheetDetent detent) {
    widget.controller.snapTo(detent);
    setState(() => _activeDetent = detent);
    widget.onSnapRequested(detent.label);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF141416),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Adjust Detents',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => widget.controller.dismiss(),
                icon: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: Colors.white60,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Demonstrates programmatic detent switching using controller.snapTo(). Tap any detent to animate.',
            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 16),

          // Detent switcher buttons
          SnapButton(
            label: 'Snap to Fraction (35%)',
            sublabel: 'Compact peek sheet',
            isSelected: _activeDetent == const DNSheetDetent.fraction(0.35),
            onTap: () => _snap(const DNSheetDetent.fraction(0.35)),
          ),
          const SizedBox(height: 10),
          SnapButton(
            label: 'Snap to Medium (50%)',
            sublabel: 'Standard half-screen sheet',
            isSelected: _activeDetent == DNSheetDetent.medium,
            onTap: () => _snap(DNSheetDetent.medium),
          ),
          const SizedBox(height: 10),
          SnapButton(
            label: 'Snap to Large (Full Height)',
            sublabel: 'Full expanded modal view',
            isSelected: _activeDetent == DNSheetDetent.large,
            onTap: () => _snap(DNSheetDetent.large),
          ),
          const SizedBox(height: 20),

          // Close button
          GestureDetector(
            onTap: () => widget.controller.dismiss(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Dismiss Sheet',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
