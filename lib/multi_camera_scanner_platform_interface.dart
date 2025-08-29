import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'multi_camera_scanner_method_channel.dart';

abstract class MultiCameraScannerPlatform extends PlatformInterface {
  /// Constructs a MultiCameraScannerPlatform.
  MultiCameraScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static MultiCameraScannerPlatform _instance = MethodChannelMultiCameraScanner();

  /// The default instance of [MultiCameraScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelMultiCameraScanner].
  static MultiCameraScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MultiCameraScannerPlatform] when
  /// they register themselves.
  static set instance(MultiCameraScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
