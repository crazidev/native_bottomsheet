import 'package:dartnative/flutter_compat.dart';
import 'package:native_bottomsheet/native_bottomsheet.dart';

class InputSheet extends StatefulWidget {
  const InputSheet({
    required this.controller,
    required this.onSubmit,
    super.key,
  });

  final DNSheetController controller;
  final void Function(String text) onSubmit;

  @override
  State<InputSheet> createState() => InputSheetState();
}

class InputSheetState extends State<InputSheet> {
  final TextEditingController _textController = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSubmit(text);
      widget.controller.dismiss();
    }
  }

  void _prefill(String text) {
    _textController.text = text;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161618),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top bar with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => widget.controller.dismiss(),
                icon: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: Color(0x998E8E93),
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Center: AI Icon & Title
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: const Center(
              child: Icon(
                MaterialSymbolsRounded.robot_2,
                color: Colors.white,
                size: 60,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Native Bottomsheet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          Text("Powered by DartNative"),
          const SizedBox(height: 40),
          Spacer(),

          // Sticky Bottom Input bar with buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF242426),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                // Voice input button
                GestureDetector(
                  onTap: () => _prefill('Voice prompt query'),
                  child: const Icon(
                    CupertinoIcons.mic_fill,
                    color: Color(0xFF8E8E93),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),

                // Native TextField
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    cursorColor: const Color(0xFFA855F7),
                    decoration: const InputDecoration(
                      hintText: 'Ask AI anything...',
                      hintStyle: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                  ),
                ),

                // Clear button (shown when text is present)
                if (_hasText) ...[
                  GestureDetector(
                    onTap: () => _textController.clear(),
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: Color(0xFF8E8E93),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Send / Submit button
                GestureDetector(
                  onTap: _hasText ? _submit : null,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _hasText
                          ? const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: _hasText ? null : const Color(0xFF3A3A3C),
                    ),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.arrow_up,
                        color: _hasText
                            ? Colors.white
                            : const Color(0xFF8E8E93),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
