/// DartNative bottom sheet plugin.
///
/// Provides native bottom sheets backed by:
/// - iOS: `UISheetPresentationController` (iOS 15+)
/// - Android: Compose `ModalBottomSheet` (Material 3)
///
/// ## Usage
/// ```dart
/// import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';
///
/// // In main() before runApp():
/// BottomSheetFFIBindings.loadSymbols();
///
/// // Show a sheet:
/// final sheet = showBottomSheet(
///   context,
///   detents: [DNSheetDetent.medium, DNSheetDetent.large],
///   builder: (ctx, ctrl) => MySheetContent(controller: ctrl),
/// );
/// ```
library;

export 'src/sheet_detent.dart';
export 'src/sheet_controller.dart';
export 'src/sheet_platform_config.dart';
export 'src/show_bottom_sheet.dart';
export 'src/sheet_list.dart';
export 'src/ffi_bindings.dart' show BottomSheetFFIBindings;
