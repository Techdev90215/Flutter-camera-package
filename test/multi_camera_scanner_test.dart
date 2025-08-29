import 'package:flutter_test/flutter_test.dart';
import 'package:multi_camera_scanner/multi_camera_scanner.dart';
import 'package:multi_camera_scanner/multi_camera_scanner_platform_interface.dart';
import 'package:multi_camera_scanner/multi_camera_scanner_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMultiCameraScannerPlatform
    with MockPlatformInterfaceMixin
    implements MultiCameraScannerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MultiCameraScannerPlatform initialPlatform = MultiCameraScannerPlatform.instance;

  test('$MethodChannelMultiCameraScanner is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMultiCameraScanner>());
  });

  test('getPlatformVersion', () async {
    MultiCameraScanner multiCameraScannerPlugin = MultiCameraScanner();
    MockMultiCameraScannerPlatform fakePlatform = MockMultiCameraScannerPlatform();
    MultiCameraScannerPlatform.instance = fakePlatform;

    expect(await multiCameraScannerPlugin.getPlatformVersion(), '42');
  });
}
