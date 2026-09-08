import 'dart:math' as math;

import 'package:dartnative/dartnative.dart';

import 'sheet_controller.dart';

/// A high-performance, progressive virtualized list optimized for bottom sheets.
///
/// Wraps [FastList] to guarantee sub-40ms sheet presentation for arbitrary list
/// lengths (1,000+ items).
///
/// **How it works:**
/// 1. **Instant Presentation**: Mounts only [initialCount] items (default: 40)
///    during the initial build, keeping frame time low (~30ms) and avoiding hitches.
/// 2. **Post-Presentation Buffer**: As soon as the native sheet completes its
///    presentation animation (notified via [DNSheetController.isPresented]),
///    an additional buffer chunk is scheduled in the background.
/// 3. **Progressive Native Appending**: As the user scrolls towards the end of
///    loaded items, subsequent chunks ([bufferChunkSize]) are appended lazily via
///    [FastList.onVisibleRange].
/// 4. **O(1) Memory & Fast Diffing**: Uses [stableItems: true] for $O(\text{chunk})$
///    diffing and [keepAliveCount: 20] to recycle native cells and discard offscreen
///    Dart subtrees.
class DNSheetList extends StatefulWidget {
  const DNSheetList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.listController,
    this.initialCount = 40,
    this.bufferChunkSize = 40,
    this.bufferThreshold = 15,
    this.keepAliveCount = 20,
    this.stableItems = true,
    this.padding,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.showScrollBar = false,
    this.onScroll,
    this.onVisibleRange,
  })  : assert(initialCount > 0, 'initialCount must be greater than 0'),
        assert(bufferChunkSize > 0, 'bufferChunkSize must be greater than 0');

  /// Total number of items in the underlying dataset.
  final int itemCount;

  /// Called to build the widget for the item at [index].
  final IndexedWidgetBuilder itemBuilder;

  /// The bottom sheet's controller. When provided, [DNSheetList] listens to
  /// [DNSheetController.isPresented] to trigger post-presentation background buffering.
  final DNSheetController? controller;

  /// Optional controller for programmatic [jumpToItem] / [scrollToItem].
  final FastListController? listController;

  /// Number of items mounted for the initial bottom sheet presentation.
  /// Defaults to 40.
  final int initialCount;

  /// Number of items to append on post-presentation and subsequent lazy loads.
  /// Defaults to 40.
  final int bufferChunkSize;

  /// Distance in items from the end of loaded items that triggers loading the next chunk.
  /// Defaults to 15.
  final int bufferThreshold;

  /// Bound the list's memory by keeping only ~visible + [keepAliveCount] rows'
  /// content built. Defaults to 20.
  final int? keepAliveCount;

  /// Declare that existing rows never change on append.
  /// Skips diffing previous items for $O(\text{chunk})$ performance.
  /// Defaults to `true`.
  final bool stableItems;

  /// Padding applied around list content.
  final EdgeInsetsGeometry? padding;

  /// Axis along which the list scrolls. Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// If `true`, the list displays items in reverse order.
  final bool reverse;

  /// Optional scroll-physics override.
  final ScrollPhysics? physics;

  /// Whether to show the vertical scroll indicator. Defaults to `false`.
  final bool showScrollBar;

  /// Called on scroll updates.
  final FastScrollCallback? onScroll;

  /// Called when the visible item range changes.
  final void Function(int firstVisible, int lastVisible)? onVisibleRange;

  @override
  State<DNSheetList> createState() => _DNSheetListState();
}

class _DNSheetListState extends State<DNSheetList> {
  late int _loadedCount;
  bool _hasTriggeredInitialBuffer = false;

  @override
  void initState() {
    super.initState();
    _loadedCount = math.min(widget.itemCount, widget.initialCount);

    if (widget.controller != null) {
      widget.controller!.addPresentedListener(_onSheetPresented);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onSheetPresented();
      });
    }
  }

  @override
  void didUpdateWidget(covariant DNSheetList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removePresentedListener(_onSheetPresented);
      widget.controller?.addPresentedListener(_onSheetPresented);
    }

    if (oldWidget.itemCount != widget.itemCount) {
      if (_loadedCount > widget.itemCount) {
        _loadedCount = widget.itemCount;
      } else if (_loadedCount < widget.initialCount && widget.itemCount > _loadedCount) {
        _loadedCount = math.min(widget.itemCount, widget.initialCount);
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removePresentedListener(_onSheetPresented);
    super.dispose();
  }

  void _onSheetPresented() {
    if (!mounted || _hasTriggeredInitialBuffer) return;
    _hasTriggeredInitialBuffer = true;

    if (_loadedCount < widget.itemCount) {
      setState(() {
        _loadedCount = math.min(widget.itemCount, _loadedCount + widget.bufferChunkSize);
      });
    }
  }

  void _handleVisibleRange(int firstVisible, int lastVisible) {
    widget.onVisibleRange?.call(firstVisible, lastVisible);

    if (_loadedCount < widget.itemCount &&
        lastVisible >= _loadedCount - widget.bufferThreshold) {
      setState(() {
        _loadedCount = math.min(widget.itemCount, _loadedCount + widget.bufferChunkSize);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FastList(
      itemCount: _loadedCount,
      itemBuilder: widget.itemBuilder,
      controller: widget.listController,
      padding: widget.padding,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      physics: widget.physics,
      showScrollBar: widget.showScrollBar,
      onScroll: widget.onScroll,
      onVisibleRange: _handleVisibleRange,
      keepAliveCount: widget.keepAliveCount,
      stableItems: widget.stableItems,
    );
  }
}
