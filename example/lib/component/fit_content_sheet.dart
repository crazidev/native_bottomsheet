import 'package:dartnative/dartnative.dart';
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';

class FitContentSheet extends StatefulWidget {
  const FitContentSheet({
    required this.controller,
    required this.onStateChanged,
  });

  final DNSheetController controller;
  final void Function(String desc) onStateChanged;

  @override
  State<FitContentSheet> createState() => FitContentSheetState();
}

class FitContentSheetState extends State<FitContentSheet> {
  int _expansionStep = 0; // 0: Compact, 1: Moderate, 2: Large

  double get _currentHeight {
    switch (_expansionStep) {
      case 0:
        return 210.0;
      case 1:
        return 330.0;
      case 2:
        return 460.0;
      default:
        return 210.0;
    }
  }

  String get _stepLabel {
    switch (_expansionStep) {
      case 0:
        return 'Compact (210px)';
      case 1:
        return 'Medium (330px)';
      case 2:
        return 'Expanded (460px)';
      default:
        return 'Default';
    }
  }

  void _cycleHeight() {
    setState(() {
      _expansionStep = (_expansionStep + 1) % 3;
    });
    widget.onStateChanged('Resized to $_stepLabel');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF18181A),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      height: _currentHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fit to Content',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Current Height: ${_currentHeight.round()}px ($_stepLabel)',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF34C759),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
          const SizedBox(height: 12),
          const Text(
            'The sheet detent automatically adapts to its intrinsic height. Tap the button below to cycle sizes smoothly.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFA1A1AA),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _cycleHeight,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'Toggle Next Size (Step ${(_expansionStep + 1) % 3})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (_expansionStep >= 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: Color(0xFF34C759),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-animation triggered! Height expanded to 330px.',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_expansionStep == 2) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    color: Color(0xFFFFD60A),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Max step reached! Notice zero bottom padding artifacts.',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
