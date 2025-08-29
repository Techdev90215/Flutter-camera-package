
import 'dart:typed_data';

/// Represents a frame captured from the camera
class CameraFrame {
  /// Raw image bytes
  final Uint8List? bytes;
  
  /// Frame dimensions
  final Size size;
  
  /// Frame rotation in degrees
  final int rotation;
  
  /// Timestamp when frame was captured
  final DateTime timestamp;

  CameraFrame({
    this.bytes,
    required this.size,
    this.rotation = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Simple Size class for dimensions
class Size {
  final double width;
  final double height;

  const Size(this.width, this.height);
}
