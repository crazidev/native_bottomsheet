import 'package:dartnative/dartnative.dart';
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';
import 'package:example/component/dartnative_plugin_registrant.dart';

class InputSheet extends StatefulWidget {
  const InputSheet({required this.controller, required this.onSubmit});

  final DNSheetController controller;
  final void Function(String text) onSubmit;

  @override
  State<InputSheet> createState() => InputSheetState();
}

class InputSheetState extends State<InputSheet> {
  final TextEditingController _textController = TextEditingController();
  String _livePreview = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C1E),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sheet with Input',
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
            'Test native keyboard interaction, focus transitions, and text inputs inside the sheet.',
            style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 16),

          // Native TextField
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3A3A3C)),
            ),
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: const Color(0xFF007AFF),
              decoration: const InputDecoration(
                hintText: 'Type your message or notes here...',
                hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                border: InputBorder.none,
              ),
              onChanged: (text) {
                setState(() {
                  _livePreview = text;
                });
              },
            ),
          ),
          const SizedBox(height: 14),

          // Quick pre-fills
          Row(
            children: [
              QuickChip(
                label: 'Quick Feedback',
                onTap: () {
                  _textController.text = 'Great bottom sheet performance! 🚀';
                  setState(() => _livePreview = _textController.text);
                },
              ),
              const SizedBox(width: 8),
              QuickChip(
                label: 'Bug Report',
                onTap: () {
                  _textController.text =
                      'Detent snapped perfectly with no glitches.';
                  setState(() => _livePreview = _textController.text);
                },
              ),
              const SizedBox(width: 8),
              QuickChip(
                label: 'Clear',
                onTap: () {
                  _textController.clear();
                  setState(() => _livePreview = '');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Live Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Preview:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _livePreview.isEmpty ? '(Nothing typed yet)' : _livePreview,
                  style: TextStyle(
                    fontSize: 13,
                    color: _livePreview.isEmpty
                        ? const Color(0xFF8E8E93)
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    widget.onSubmit(_textController.text);
                    widget.controller.dismiss();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Submit & Close',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
