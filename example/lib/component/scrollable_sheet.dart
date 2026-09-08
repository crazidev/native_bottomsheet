import 'package:dartnative/dartnative.dart';
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';
import 'package:example/main.dart';

class ScrollableSheet extends StatefulWidget {
  const ScrollableSheet({
    required this.controller,
    required this.onSnapRequested,
  });

  final DNSheetController controller;
  final void Function(String label) onSnapRequested;

  @override
  State<ScrollableSheet> createState() => ScrollableSheetState();
}

class ScrollableSheetState extends State<ScrollableSheet> {
  DNSheetDetent _activeDetent = DNSheetDetent.medium;

  void _snap(DNSheetDetent detent) {
    widget.controller.snapTo(detent);
    setState(() => _activeDetent = detent);
    widget.onSnapRequested(detent.label);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF141416),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scrollable Content (FastList)',
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
                  '1,000 recycled rows via native FastList (UITableView). O(1) memory and instant presentation.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SnapButton(
                        label: 'Medium',
                        isSelected: _activeDetent == DNSheetDetent.medium,
                        onTap: () => _snap(DNSheetDetent.medium),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SnapButton(
                        label: 'Large',
                        isSelected: _activeDetent == DNSheetDetent.large,
                        onTap: () => _snap(DNSheetDetent.large),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: DNSheetList(
              controller: widget.controller,
              itemCount: 5000,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2C2C2E), width: 0.5),
                    ),
                  ),
                  child: Text(
                    "Row $index",
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
