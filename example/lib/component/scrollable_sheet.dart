import 'package:dartnative/dartnative.dart';
import 'package:native_bottomsheet/native_bottomsheet.dart';

class ScrollableSheet extends StatefulWidget {
  const ScrollableSheet({
    required this.controller,
    required this.onSnapRequested,
  });

  final DNSheetController controller;
  final void Function(String label) onSnapRequested;

  @override
  State<ScrollableSheet> createState() => _ScrollableSheetState();
}

class _ScrollableSheetState extends State<ScrollableSheet> {
  DNSheetDetent _activeDetent = DNSheetDetent.medium;

  @override
  void initState() {
    print("===== Init state");
    widget.controller.addDetentListener(detendListener);
    super.initState();
  }

  void detendListener(DNSheetDetent sheet) {
    print("Detent state changed $sheet");
    setState(() {
      _activeDetent = sheet;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scrollable Content"),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: () => widget.controller.dismiss(),
        ),
        toolbarHeight: 0,

        actions: [
          IconButton(
            icon: Icon(
              _activeDetent == .medium
                  ? CupertinoIcons.rectangle_expand_vertical
                  : CupertinoIcons.rectangle_compress_vertical,
            ),
            onPressed: () {
              _activeDetent = _activeDetent == .medium ? .large : .medium;
              setState(() {});
              widget.controller.snapTo(_activeDetent);
            },
          ),
        ],
      ),
      brightness: Brightness.dark,
      backgroundColor: const Color(0xFF141416),
      body: Expanded(
        child: Container(
          height: 600,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 40),
                child: FastList(
                  itemCount: 100,
                  showScrollBar: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFF2C2C2E),
                            width: 0.5,
                          ),
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
        ),
      ),
    );
  }
}
