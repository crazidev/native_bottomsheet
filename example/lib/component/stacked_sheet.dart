import 'package:dartnative/dartnative.dart';
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';
import 'package:example/main.dart';

class StackedSheet extends StatelessWidget {
  const StackedSheet({
    super.key,
    required this.controller,
    required this.level,
  });

  final DNSheetController controller;
  final int level;

  void _openNextSheet(BuildContext context) {
    showBottomSheet(
      context,
      detents: const [DNSheetDetent.medium, DNSheetDetent.large],
      initialDetent: controller.currentDetent ?? DNSheetDetent.medium,
      showGrabber: true,
      backgroundColor: const Color(0xFF141416),
      builder: (ctx, ctrl) => StackedSheet(controller: ctrl, level: level + 1),
    );
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
              Text(
                'Sheet Level $level',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => controller.dismiss(),
                icon: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: Colors.white60,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This is sheet level $level. You can open another sheet on top of this one to test stacked bottom sheets.',
            style: const TextStyle(fontSize: 15, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SnapButton(
                  label: 'Open Sheet Level ${level + 1}',
                  isSelected: false,
                  onTap: () => _openNextSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
