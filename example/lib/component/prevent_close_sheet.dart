import 'package:dartnative/dartnative.dart';
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';

class PreventCloseSheet extends StatelessWidget {
  const PreventCloseSheet({
    required this.controller,
    required this.attemptCount,
    required this.onExplicitClose,
  });

  final DNSheetController controller;
  final int attemptCount;
  final VoidCallback onExplicitClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C1E),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                CupertinoIcons.lock_shield_fill,
                color: Color(0xFFFF9500),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Non-Dismissable Sheet',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFF9500).withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dismissal Locked (isDismissable: false)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9500),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Try pulling down the sheet or tapping the dark background scrim. The native gesture recognizer rejects it and triggers onDismissAttempted.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dismiss attempts detected: $attemptCount',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This pattern is ideal for mandatory confirmation dialogs, payment approvals, or forms requiring unsaved change warnings before exit.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8E8E93),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onExplicitClose,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Confirm & Close Sheet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
