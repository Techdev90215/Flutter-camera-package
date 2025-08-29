
export 'src/controllers/camera_controller.dart';
export 'src/models/camera_config.dart';
export 'src/models/camera_mode.dart';
export 'src/models/barcode_result.dart';
export 'src/widgets/camera_preview_widget.dart';

import 'multi_camera_scanner_platform_interface.dart';

/// Main entry point for the multi_camera_scanner package
class MultiCameraScanner {
  /// Get the platform version
  Future<String?> getPlatformVersion() {
    return MultiCameraScannerPlatform.instance.getPlatformVersion();
  }
}
