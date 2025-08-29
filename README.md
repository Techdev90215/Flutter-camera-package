# Multi Camera Scanner

A Flutter package that provides different camera and barcode scanner features combined. This package supports photo capture, video recording, and real-time barcode scanning across iOS, Android, and Web platforms.

## Features

### Iteration 1 (Current)
- ✅ **Camera Preview**: Stream of camera preview
- ✅ **Photo Capture**: Take pictures on trigger
- ✅ **Video Recording**: Start and stop video recording
- ✅ **Barcode Scanning**: Real-time barcode detection with bounding boxes
- ✅ **Cross-Platform**: iOS, Android, and Web support
- ✅ **Lifecycle Management**: Proper resource handling and app lifecycle management
- ✅ **Example App**: Comprehensive demo showing all functionality

### Coming in Iteration 2
- 🔄 **ML Kit Integration**: Client-side barcode detection with MLKit/AI Core on iOS/Android
- 🔄 **ZXing Web**: Client-side barcode detection with ZXing for Web
- 🔄 **Image Analysis**: Analyze single images from gallery/file picker
- 🔄 **Advanced Controls**: Flash, camera switching, focus controls

### Coming in Iteration 3
- 📚 **Documentation**: Complete API documentation
- 🧪 **Testing**: Comprehensive test coverage
- 🚀 **Performance**: Optimization and performance improvements

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  multi_camera_scanner: ^0.0.1
```

## Usage

### Basic Setup

```dart
import 'package:multi_camera_scanner/multi_camera_scanner.dart';

// Create a camera controller
final cameraController = CameraController(
  config: CameraConfig(
    initialMode: CameraMode.photo,
    resolution: CameraResolution.high,
    enableAudio: true,
    flashMode: FlashMode.auto,
  ),
);

// Initialize the camera
await cameraController.initialize();
```

### Camera Preview Widget

```dart
CameraPreviewWidget(
  controller: cameraController,
  config: CameraPreviewConfig(
    showControls: true,
    showLoadingIndicator: true,
  ),
  onBarcodeDetected: (barcode) {
    print('Detected barcode: ${barcode.value}');
  },
)
```

### Taking Photos

```dart
// Switch to photo mode
await cameraController.setMode(CameraMode.photo);

// Take a picture
final imagePath = await cameraController.takePicture();
print('Picture saved to: $imagePath');
```

### Recording Video

```dart
// Switch to video mode
await cameraController.setMode(CameraMode.video);

// Start recording
await cameraController.startVideo();

// Stop recording
final videoPath = await cameraController.stopVideo();
print('Video saved to: $videoPath');
```

### Barcode Scanning

```dart
// Switch to barcode mode
await cameraController.setMode(CameraMode.barcode);

// Listen to detected barcodes
cameraController.barcodeStream.listen((barcodes) {
  for (final barcode in barcodes) {
    print('Barcode: ${barcode.value} (${barcode.format.displayName})');
    print('Confidence: ${(barcode.confidence * 100).toStringAsFixed(0)}%');
    print('Bounding box: ${barcode.boundingBox}');
  }
});
```

### Configuration Options

```dart
CameraConfig(
  initialMode: CameraMode.photo,
  resolution: CameraResolution.high,
  enableAudio: true,
  flashMode: FlashMode.auto,
  maxVideoDuration: Duration(seconds: 30),
  videoFrameRate: 30,
  barcodeDetectionInterval: Duration(milliseconds: 500),
  detectMultipleBarcodes: true,
  minBarcodeConfidence: 0.7,
  autoFocus: true,
  preferredCameraPosition: CameraPosition.back,
)
```

## Supported Barcode Formats

- **QR Code** - Quick Response codes
- **Data Matrix** - 2D matrix barcodes
- **Code 128** - High-density linear barcode
- **Code 39** - Alpha-numeric barcode
- **EAN-13** - European Article Number
- **EAN-8** - Shortened EAN
- **UPC-A** - Universal Product Code
- **UPC-E** - Shortened UPC
- **PDF417** - 2D stacked barcode
- **Aztec** - 2D matrix barcode
- **ITF** - Interleaved 2 of 5

## Platform Support

### iOS
- Camera permissions handled automatically
- Photo and video capture
- Real-time barcode detection (coming in Iteration 2)

### Android
- Camera permissions handled automatically
- Photo and video capture
- Real-time barcode detection (coming in Iteration 2)

### Web
- Camera access via getUserMedia()
- Photo and video capture
- Barcode detection via ZXing (coming in Iteration 2)

## Example App

The package includes a comprehensive example app that demonstrates:

- Mode switching between photo, video, and barcode
- Photo capture with success feedback
- Video recording with start/stop controls
- Real-time barcode detection display
- Barcode history and management
- Error handling and user feedback

To run the example:

```bash
cd example
flutter run
```

## Architecture

The package follows a clean architecture pattern:

```
lib/
├── multi_camera_scanner.dart          # Main package entry point
├── src/
│   ├── controllers/                   # Business logic controllers
│   │   ├── camera_controller.dart     # Main camera controller
│   │   └── barcode_controller.dart    # Barcode scanning logic
│   ├── models/                        # Data models
│   │   ├── camera_config.dart         # Camera configuration
│   │   ├── camera_mode.dart           # Camera operation modes
│   │   └── barcode_result.dart        # Barcode detection results
│   ├── services/                      # Platform-specific services
│   │   ├── barcode_detector_service.dart  # Barcode detection
│   │   └── image_analyzer_service.dart     # Image analysis
│   └── widgets/                       # UI components
│       ├── camera_preview_widget.dart # Main camera preview
│       └── barcode_overlay_widget.dart # Barcode overlay
```

## State Management

The package uses streams for reactive state management:

- **State Stream**: Camera state changes (initializing, ready, taking picture, etc.)
- **Error Stream**: Error messages and exceptions
- **Barcode Stream**: Real-time barcode detection results

## Error Handling

The package provides comprehensive error handling:

```dart
try {
  await cameraController.takePicture();
} on CameraException catch (e) {
  print('Camera error: ${e.message}');
  print('State: ${e.state}');
  print('Cause: ${e.cause}');
}
```

## Lifecycle Management

The package properly handles app lifecycle:

- Automatic resource cleanup on dispose
- Permission management
- State preservation during app lifecycle changes
- Memory management for camera resources

## Contributing

This is an open-source project. Contributions are welcome!

### Development Setup

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Run tests: `flutter test`
4. Run the example: `cd example && flutter run`

### Code Style

- Follow Flutter/Dart style guidelines
- Use meaningful variable and function names
- Add comprehensive documentation
- Include unit tests for new features

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Roadmap

### Iteration 1 (Current) ✅
- Basic camera functionality
- Photo and video capture
- Barcode scanning framework
- Cross-platform support
- Example application

### Iteration 2 (Next)
- ML Kit integration for mobile
- ZXing integration for web
- Image analysis from gallery
- Advanced barcode detection

### Iteration 3 (Final)
- Performance optimization
- Comprehensive testing
- Complete documentation
- Performance benchmarks

## Support

For support, please:

1. Check the [example app](example/) for usage examples
2. Review the [API documentation](lib/)
3. Open an [issue](https://github.com/your-repo/issues) for bugs
4. Open a [discussion](https://github.com/your-repo/discussions) for questions

## Acknowledgments

- Built with Flutter and Dart
- Uses CameraAwesome for camera functionality
- Integrates with Google ML Kit for barcode detection
- Web support via ZXing library

