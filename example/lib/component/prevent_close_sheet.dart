import 'package:dartnative/dartnative.dart';
import 'package:native_bottomsheet/native_bottomsheet.dart';

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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Prevent Close',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.lock_shield_fill,
                color: Color(0xFFFF9500),
                size: 100,
              ),
              const Text(
                'You can\'t close this sheet until you click the button below',
                style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          Spacer(),
          Align(
            alignment: Alignment.center,
            child: Text(
              "Powered by DartNative",
              style: TextStyle(color: Colors.blue, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: onExplicitClose,
            child: GlassEffectContainer(
              style: GlassStyle.regular,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'Click me to close the sheet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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
