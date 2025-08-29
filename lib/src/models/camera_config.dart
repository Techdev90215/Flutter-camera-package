// lib/src/models/camera_config.dart

import 'package:multi_camera_scanner/src/models/camera_mode.dart';
import 'package:multi_camera_scanner/src/models/barcode_result.dart';

///Resolution presets for camera configuration
/// Resolution presets for camera configuration
enum CameraResolution {
  /// Low resolution (480p)
  low,
  /// Medium resolution (720p)
  medium,
  /// High resolution (1080p)
  high,
  /// Very high resolution (4K)
  veryHigh,
  /// Maximum available resolution
  max,
}

/// Configuration for flash modes
enum FlashMode {
  /// Flash is disabled
  off,
  /// Flash fires automatically when needed
  auto,
  /// Flash is always on
  on,
  /// Flash is used as torch (continuous light)
  torch,
}

/// A configuration class for the camera controller to specify operational parameters.
/// This allows for future expansion with settings like resolution, frame rate, etc.
class CameraConfig {
  /// The initial mode for the camera to start in.
  final CameraMode initialMode;

  /// The resolution preset for camera preview and capture.
  final CameraResolution resolution;

  /// Whether to enable audio recording for video mode.
  final bool enableAudio;

  /// Flash mode setting.
  final FlashMode flashMode;

  /// Maximum duration for video recording (null for unlimited).
  final Duration? maxVideoDuration;

  /// Frame rate for video recording.
  final int? videoFrameRate;

  /// Enabled barcode formats for detection.
  /// If empty, all supported formats will be enabled.
  final Set<BarcodeFormat> enabledBarcodeFormats;

  /// Interval between barcode detection attempts.
  /// Shorter intervals provide faster detection but use more CPU.
  final Duration barcodeDetectionInterval;

  /// Whether to detect multiple barcodes simultaneously.
  /// If false, only the first detected barcode will be returned.
  final bool detectMultipleBarcodes;

  /// Minimum confidence threshold for barcode detection (0.0 to 1.0).
  final double minBarcodeConfidence;

  /// Whether to automatically focus the camera.
  final bool autoFocus;

  /// Preferred camera position (front or back).
  final CameraPosition preferredCameraPosition;

  const CameraConfig({
    this.initialMode = CameraMode.photo,
    this.resolution = CameraResolution.high,
    this.enableAudio = true,
    this.flashMode = FlashMode.auto,
    this.maxVideoDuration,
    this.videoFrameRate = 30,
    this.enabledBarcodeFormats = const {},
    this.barcodeDetectionInterval = const Duration(milliseconds: 100),
    this.detectMultipleBarcodes = true,
    this.minBarcodeConfidence = 0.5,
    this.autoFocus = true,
    this.preferredCameraPosition = CameraPosition.back,
  });

  /// Creates a copy of this config with some fields replaced.
  CameraConfig copyWith({
    CameraMode? initialMode,
    CameraResolution? resolution,
    bool? enableAudio,
    FlashMode? flashMode,
    Duration? maxVideoDuration,
    int? videoFrameRate,
    Set<BarcodeFormat>? enabledBarcodeFormats,
    Duration? barcodeDetectionInterval,
    bool? detectMultipleBarcodes,
    double? minBarcodeConfidence,
    bool? autoFocus,
    CameraPosition? preferredCameraPosition,
  }) {
    return CameraConfig(
      initialMode: initialMode ?? this.initialMode,
      resolution: resolution ?? this.resolution,
      enableAudio: enableAudio ?? this.enableAudio,
      flashMode: flashMode ?? this.flashMode,
      maxVideoDuration: maxVideoDuration ?? this.maxVideoDuration,
      videoFrameRate: videoFrameRate ?? this.videoFrameRate,
      enabledBarcodeFormats: enabledBarcodeFormats ?? this.enabledBarcodeFormats,
      barcodeDetectionInterval: barcodeDetectionInterval ?? this.barcodeDetectionInterval,
      detectMultipleBarcodes: detectMultipleBarcodes ?? this.detectMultipleBarcodes,
      minBarcodeConfidence: minBarcodeConfidence ?? this.minBarcodeConfidence,
      autoFocus: autoFocus ?? this.autoFocus,
      preferredCameraPosition: preferredCameraPosition ?? this.preferredCameraPosition,
    );
  }

  /// Gets the effective barcode formats (all supported if none specified).
  Set<BarcodeFormat> get effectiveBarcodeFormats {
    if (enabledBarcodeFormats.isEmpty) {
      return {
        BarcodeFormat.qrCode,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      };
    }
    return enabledBarcodeFormats;
  }

  @override
  String toString() {
    return 'CameraConfig(initialMode: $initialMode, resolution: $resolution, enableAudio: $enableAudio)';
  }
}

/// Camera position enumeration
enum CameraPosition {
  /// Back-facing camera
  back,
  /// Front-facing camera
  front,
}