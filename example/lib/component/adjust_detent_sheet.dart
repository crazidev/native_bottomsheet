import 'package:dartnative/dartnative.dart';
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';

class AdjustDetentSheet extends StatefulWidget {
  const AdjustDetentSheet({
    required this.controller,
    required this.onSnapRequested,
    super.key,
  });

  final DNSheetController controller;
  final void Function(String label) onSnapRequested;

  @override
  State<AdjustDetentSheet> createState() => AdjustDetentSheetState();
}

class _DetentCardItem {
  final DNSheetDetent detent;
  final double ratio;
  final String label;

  const _DetentCardItem({
    required this.detent,
    required this.ratio,
    required this.label,
  });
}

class AdjustDetentSheetState extends State<AdjustDetentSheet> {
  DNSheetDetent _activeDetent = const DNSheetDetent.fraction(0.35);
  bool startAnimating = false;

  static const List<_DetentCardItem> _items = [
    _DetentCardItem(
      detent: DNSheetDetent.fraction(0.35),
      ratio: 0.35,
      label: '35%',
    ),
    _DetentCardItem(detent: DNSheetDetent.medium, ratio: 0.50, label: '50%'),
    _DetentCardItem(detent: DNSheetDetent.large, ratio: 1.00, label: '100%'),
  ];

  @override
  void initState() {
    super.initState();
    _activeDetent =
        widget.controller.currentDetent ?? const DNSheetDetent.fraction(0.35);
    widget.controller.addDetentListener(_onDetentChanged);
    _startEntranceAnimation();
  }

  @override
  void dispose() {
    widget.controller.removeDetentListener(_onDetentChanged);
    super.dispose();
  }

  void _onDetentChanged(DNSheetDetent detent) {
    if (mounted) {
      setState(() => _activeDetent = detent);
    }
  }

  void _startEntranceAnimation() {
    Future.delayed(const Duration(milliseconds: 300)).then((_) {
      if (mounted) {
        setState(() => startAnimating = true);
      }
    });
  }

  void _snap(DNSheetDetent detent) {
    widget.controller.snapTo(detent);
    setState(() => _activeDetent = detent);
    widget.onSnapRequested(detent.label);
  }

  @override
  Widget build(BuildContext context) {
    const double cardHeight = 80.0;
    const double cardWidth = 60.0;
    const double innerPadding = 6.0;

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
            style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
          ),

          const SizedBox(height: 30),

          // Detent switcher cards
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 24),
                  () {
                    final item = _items[i];
                    final isSelected = _activeDetent == item.detent;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _snap(item.detent),
                      child: Container(
                        height: cardHeight,
                        width: cardWidth,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.grey,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(innerPadding),
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 1000),
                          curve: Curves.decelerate,
                          height: startAnimating
                              ? cardHeight *
                                    switch (i) {
                                      0 => 30,
                                      1 => 50,
                                      2 => 80,
                                      _ => 0,
                                    } /
                                    100
                              : 0,
                          width: 45,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.grey,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(5),
                            color: isSelected
                                ? Colors.white
                                : const Color(0x14FFFFFF),
                          ),
                        ),
                      ),
                    );
                  }(),
                ],
              ].reversed.toList(),
            ),
          ),
        ],
      ),
    );
  }
}
