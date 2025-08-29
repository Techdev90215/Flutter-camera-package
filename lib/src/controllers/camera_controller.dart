// lib/src/controllers/camera_controller.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camerawesome/camerawesome_plugin.dart' as awesome;
// Camerawesome types are mostly used dynamically via native controller

// Camerawesome types are consumed indirectly via the preview widget; avoid direct imports here
import 'package:flutter/foundation.dart';
import 'package:multi_camera_scanner/src/controllers/barcode_controller.dart';
import 'package:multi_camera_scanner/src/models/barcode_result.dart';
import 'package:multi_camera_scanner/src/models/camera_config.dart' as appcfg;
import 'package:multi_camera_scanner/src/models/camera_mode.dart';
import 'package:multi_camera_scanner/src/models/camera_frame.dart';
import 'package:multi_camera_scanner/src/services/image_analyzer_service.dart';


/// Represents the state of the camera controller
enum CameraState {
  /// Camera is not initialized
  uninitialized,
  /// Camera is initializing
  initializing,
  /// Camera is ready for use
  ready,
  /// Camera is taking a photo
  takingPicture,
  /// Camera is recording video
  recordingVideo,
  /// Camera is scanning barcodes
  scanningBarcodes,
  /// Camera has encountered an error
  error,
  /// Camera is disposed
  disposed,
}

/// Exception thrown when camera operations fail
class CameraException implements Exception {
  final String message;
  final CameraState? state;
  final Object? cause;
  const CameraException(this.message, {this.state, this.cause});
  @override
  String toString() => 'CameraException: $message${state != null ? ' (State: $state)' : ''}${cause != null ? ' - ${cause.toString()}' : ''}';
}

/// The main public API controller for the multi_camera_scanner package.
///
/// This class orchestrates the camera state, manages different capture modes,
/// and exposes streams and methods for interacting with the camera.
class CameraController with ChangeNotifier {
  // --- Private Properties ---
  final BarcodeController _barcodeController;
  final ImageAnalyzerService _imageAnalyzerService;

  Object? _nativeController;

  CameraMode _currentMode;
  CameraState _state = CameraState.uninitialized;
  String? _lastError;

  // Video recording state
  bool _isRecordingVideo = false;
  DateTime? _videoRecordingStartTime;
  Completer<String>? _pendingPhotoPath;
  Completer<String>? _pendingVideoPath;

  Future<bool> _awaitVideoMode({Duration timeout = const Duration(seconds: 2)}) async {
    final start = DateTime.now();
    bool isVideo = false;
    while (DateTime.now().difference(start) < timeout) {
      try {
        // Direct check on captureMode if available
        try {
          final mode = (_nativeController as dynamic).captureMode;
          if (mode == awesome.CaptureMode.video) return true;
        } catch (_) {}
        (_nativeController as dynamic).when(
          onPreparingCamera: (_) {},
          onPhotoMode: (_) {},
          onVideoMode: (_) { isVideo = true; },
          onVideoRecordingMode: (_) { isVideo = true; },
        );
      } catch (_) {}
      if (isVideo) return true;
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  // Streams for state management
  final _stateStreamController = StreamController<CameraState>.broadcast();
  final _errorStreamController = StreamController<String?>.broadcast();

  // --- Public Properties ---

  /// The current operational mode of the camera.
  CameraMode get currentMode => _currentMode;

  /// The current state of the camera.
  CameraState get state => _state;

  /// The last error message (null if no error).
  String? get lastError => _lastError;

  /// Whether the camera is currently initialized and ready.
  bool get isInitialized => _state == CameraState.ready || 
                           _state == CameraState.takingPicture ||
                           _state == CameraState.recordingVideo ||
                           _state == CameraState.scanningBarcodes;

  /// Whether video is currently being recorded.
  bool get isRecordingVideo => _isRecordingVideo;

  /// Duration of current video recording (null if not recording).
  Duration? get videoRecordingDuration {
    if (!_isRecordingVideo || _videoRecordingStartTime == null) return null;
    return DateTime.now().difference(_videoRecordingStartTime!);
  }

  /// Stream of detected barcodes, active only when in [CameraMode.barcode].
  Stream<List<BarcodeResult>> get barcodeStream => _barcodeController.stream;

  /// Stream of camera state changes.
  Stream<CameraState> get stateStream => _stateStreamController.stream;

  /// Stream of error messages.
  Stream<String?> get errorStream => _errorStreamController.stream;

  // --- Constructor ---

  Object? get nativeController => _nativeController;

  /// Attach the underlying native camera controller/state (from Camerawesome builder)
  void attachNativeController(Object controller) {
    _nativeController = controller;
  }


  CameraController({appcfg.CameraConfig config = const appcfg.CameraConfig()})
      : _currentMode = config.initialMode,
        _barcodeController = BarcodeController(config: config),
        _imageAnalyzerService = ImageAnalyzerService(config: config);

  // --- Public Methods ---

  /// Initialize the camera controller and its dependencies.
  Future<void> initialize() async {
    if (_state == CameraState.disposed) {
      throw const CameraException('Cannot initialize a disposed controller');
    }

    if (isInitialized || _state == CameraState.initializing) {
      return;
    }

    _updateState(CameraState.initializing);

    try {
      await _initializeServices();
      await _initializeCamera();
      
      _updateState(CameraState.ready);
      debugPrint('CameraController initialized successfully');
    } catch (e) {
      final error = 'Failed to initialize camera: ${e.toString()}';
      _setError(error, CameraState.error);
      throw CameraException(error, state: _state, cause: e);
    }
  }

  /// Initialize internal services
  Future<void> _initializeServices() async {
    await _barcodeController.initialize();
    await _imageAnalyzerService.initialize();
  }

  /// Initialize the native camera - handled by the preview widget
  Future<void> _initializeCamera() async {}

  // SaveConfig is handled by the preview widget configuration


  // AnalysisConfig is handled by the preview widget configuration

  /// Switches the camera's operational mode.
  ///
  /// This will reconfigure the underlying native camera session.
  Future<void> setMode(CameraMode newMode) async {
    if (!isInitialized) {
      throw const CameraException('Cannot switch mode when not initialized');
    }

    if (_currentMode == newMode) return;

    final previousMode = _currentMode;
    
    try {
      // Stop any ongoing operations
      await _stopCurrentModeOperations();
      
      _currentMode = newMode;
      
      // Configure camera for new mode
      await _configureForMode(newMode);
      
      debugPrint('Switched camera mode from $previousMode to $newMode');
      notifyListeners();
    } catch (e) {
      // Revert on error
      _currentMode = previousMode;
      final error = 'Failed to switch to mode $newMode: ${e.toString()}';
      _setError(error);
      throw CameraException(error, cause: e);
    }
  }

  /// Configure camera for the specified mode
  Future<void> _configureForMode(CameraMode mode) async {
    // Drive Camerawesome state to requested mode
    try {
      final native = _nativeController as dynamic;
      native.when(
        onPreparingCamera: (_) {},
        onPhotoMode: (s) {
          if (mode == CameraMode.video) s.toVideoMode();
        },
        onVideoMode: (s) {
          if (mode == CameraMode.photo) s.toPhotoMode();
        },
        onVideoRecordingMode: (s) {
          if (mode == CameraMode.photo) s.stopRecording();
        },
      );
    } catch (_) {}

    if (mode == CameraMode.barcode) {
      _barcodeController.startScanning();
      _updateState(CameraState.scanningBarcodes);
    } else {
      _updateState(CameraState.ready);
    }
  }

  /// Stop operations for the current mode
  Future<void> _stopCurrentModeOperations() async {
    switch (_currentMode) {
      case CameraMode.video:
        if (_isRecordingVideo) {
          await stopVideo();
        }
        break;
      case CameraMode.barcode:
        _barcodeController.stopScanning();
        break;
      case CameraMode.photo:
        // No ongoing operations to stop for photo mode
        break;
    }
  }

  /// Captures a single picture.
  ///
  /// Throws an error if not in [CameraMode.photo].
  Future<String> takePicture() async {
    _validateState([CameraState.ready]);
    if (_currentMode != CameraMode.photo) throw const CameraException('Cannot take picture when not in photo mode');
    _updateState(CameraState.takingPicture);

    try {
      _pendingPhotoPath = Completer<String>();
      await (_nativeController as dynamic).takePhoto();
      final path = await _pendingPhotoPath!.future;
      _updateState(CameraState.ready);
      return path;
    } catch (e) {
      _updateState(CameraState.ready);
      final error = 'Failed to take picture: ${e.toString()}';
      _setError(error);
      throw CameraException(error, cause: e);
    }
  }

  /// Starts video recording.
  ///
  /// Throws an error if not in [CameraMode.video].
  Future<void> startVideo() async {
    _validateState([CameraState.ready]);
    if (_currentMode != CameraMode.video) throw const CameraException('Cannot start video when not in video mode');
    if (_isRecordingVideo) throw const CameraException('Video recording already in progress');

    try {
      // Request switch to video mode if currently in photo
      try {
        (_nativeController as dynamic).when(
          onPreparingCamera: (_) {},
          onPhotoMode: (s) { try { s.toVideoMode(); } catch (_) {} },
          onVideoMode: (_) {},
          onVideoRecordingMode: (_) {},
        );
      } catch (_) {}
      // Fallback: explicitly set capture mode to video
      try { (_nativeController as dynamic).setCaptureMode(awesome.CaptureMode.video); } catch (_) {}
      // Wait for state to become video
      final ok = await _awaitVideoMode();
      if (!ok) {
        throw const CameraException('Failed to switch to video mode');
      }
      // Start recording from the correct state
      bool started = false;
      try {
        (_nativeController as dynamic).when(
          onPreparingCamera: (_) {},
          onPhotoMode: (_) {},
          onVideoMode: (s) { s.startRecording(); started = true; },
          onVideoRecordingMode: (_) { started = true; },
        );
      } catch (_) {}
      if (!started) {
        await (_nativeController as dynamic).startRecording();
      }
      _isRecordingVideo = true;
      _videoRecordingStartTime = DateTime.now();
      _updateState(CameraState.recordingVideo);
      debugPrint('Video recording started');
    } catch (e) {
      _isRecordingVideo = false;
      _videoRecordingStartTime = null;
      final error = 'Failed to start video recording: ${e.toString()}';
      _setError(error);
      throw CameraException(error, cause: e);
    }
  }

Future<void> processImageForBarcodes(CameraFrame frame) async {
  if (_currentMode != CameraMode.barcode || !isInitialized) return;
  
  final bytes = frame.bytes;
  if (bytes == null) return;
  
  try {
    // Process the frame through your barcode detector service
    final barcodes = await _barcodeController.processFrame(
      bytes,
      frame.size.width.toInt(),
      frame.size.height.toInt(),
      frame.rotation,
    );
    
    // Update the barcode stream
    _barcodeController.updateDetectedBarcodes(barcodes);
  } catch (e) {
    debugPrint('Error processing barcode frame: $e');
  }
}

  /// Stops video recording and returns the file path.
  Future<String> stopVideo() async {
    if (!_isRecordingVideo) throw const CameraException('No video recording in progress');

    try {
      _pendingVideoPath = Completer<String>();
      bool stopped = false;
      try {
        (_nativeController as dynamic).when(
          onPreparingCamera: (_) {},
          onPhotoMode: (_) {},
          onVideoMode: (_) {},
          onVideoRecordingMode: (s) { s.stopRecording(); stopped = true; },
        );
      } catch (_) {}
      if (!stopped) {
        await (_nativeController as dynamic).stopRecording();
      }
      final duration = videoRecordingDuration;
      _isRecordingVideo = false;
      _videoRecordingStartTime = null;
      final path = await _pendingVideoPath!.future;
      _updateState(CameraState.ready);
      debugPrint('Video recording stopped. Duration: ${duration?.inSeconds}s, Path: $path');
      return path;
    } catch (e) {
      final error = 'Failed to stop video recording: ${e.toString()}';
      _setError(error);
      throw CameraException(error, cause: e);
    }
  }

  /// Handle Camerawesome media capture events to resolve pending paths
  void handleMediaCaptureEvent(dynamic event) {
    try {
      final status = event.status?.toString() ?? '';
      final isSuccess = status.toLowerCase().contains('success');
      if (!isSuccess) return;

      String? extractPath(dynamic req) {
        try {
          final file = req.file; // single
          if (file != null && file.path != null) return file.path as String;
        } catch (_) {}
        try {
          final path = req.path; // some versions
          if (path is String) return path;
        } catch (_) {}
        try {
          if (req.fileBySensor is Map) {
            final values = (req.fileBySensor as Map).values;
            if (values.isNotEmpty) {
              final first = values.first;
              if (first != null && first.path != null) return first.path as String;
            }
          }
        } catch (_) {}
        return null;
      }

      String? path;
      try {
        // captureRequest.when(single: (s) => ..., multiple: (m) => ...)
        final when = event.captureRequest.when;
        path = when(
          single: (s) => extractPath(s),
          multiple: (m) => extractPath(m),
        ) as String?;
      } catch (_) {
        // Fallback attempt
        path = extractPath(event.captureRequest);
      }

      if (path == null) return;

      final isPicture = (event.isPicture == true) || status.toLowerCase().contains('picture');
      final isVideo = (event.isVideo == true) || status.toLowerCase().contains('video');

      if (isPicture && _pendingPhotoPath != null && !_pendingPhotoPath!.isCompleted) {
        _pendingPhotoPath!.complete(path);
      } else if (isVideo && _pendingVideoPath != null && !_pendingVideoPath!.isCompleted) {
        _pendingVideoPath!.complete(path);
      }
    } catch (e) {
      debugPrint('Failed to handle media capture event: $e');
    }
  }

  /// Analyzes a static image file for barcodes.
  Future<List<BarcodeResult>> analyzeImage(File imageFile) async {
    if (!isInitialized) {
      throw const CameraException('Camera not initialized');
    }

    try {
      return await _imageAnalyzerService.analyzeImage(imageFile);
    } catch (e) {
      final error = 'Failed to analyze image: ${e.toString()}';
      _setError(error);
      throw CameraException(error, cause: e);
    }
  }

  /// Analyzes image bytes for barcodes (useful for web file uploads).
  Future<List<BarcodeResult>> analyzeImageBytes(Uint8List imageBytes, {String? filename}) async {
    if (!isInitialized) {
      throw const CameraException('Camera not initialized');
    }

    try {
      return await _imageAnalyzerService.analyzeImageBytes(imageBytes, filename: filename);
    } catch (e) {
      final error = 'Failed to analyze image bytes: ${e.toString()}';
      _setError(error);
      throw CameraException(error, cause: e);
    }
  }

  /// Toggle flash mode (if supported)
   Future<void> setFlashMode(appcfg.FlashMode flashMode) async {
    _validateState([CameraState.ready, CameraState.scanningBarcodes]);
    try {
      // Map to Camerawesome flashes
      final caFlash = () {
        switch (flashMode) {
          case appcfg.FlashMode.on:
            return awesome.FlashMode.on;
          case appcfg.FlashMode.off:
            return awesome.FlashMode.none;
          case appcfg.FlashMode.torch:
            return awesome.FlashMode.always;
          case appcfg.FlashMode.auto:
            return awesome.FlashMode.auto;
        }
      }();

      // Apply flash per concrete state if needed
      bool applied = false;
      try {
        (_nativeController as dynamic).when(
          onPreparingCamera: (_) {},
          onPhotoMode: (s) { try { s.setFlashMode(caFlash); applied = true; } catch (_) {} },
          onVideoMode: (s) { try { s.setFlashMode(caFlash); applied = true; } catch (_) {} },
          onVideoRecordingMode: (s) { try { s.setFlashMode(caFlash); applied = true; } catch (_) {} },
        );
      } catch (_) {}
      if (!applied) {
        await (_nativeController as dynamic).setFlashMode(caFlash);
      }
      debugPrint('Flash mode set to: $flashMode');
      notifyListeners();
    } catch (e) {
      final error = 'Failed to set flash mode: ${e.toString()}';
      _setError(error);
      throw CameraException(error, cause: e);
    }
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    _validateState([CameraState.ready, CameraState.scanningBarcodes]);
    try {
      await (_nativeController as dynamic).switchCameraSensor();
      debugPrint('Camera switched');
      notifyListeners();
    } catch (e) {
      final error = 'Failed to switch camera: ${e.toString()}';
      _setError(error);
      throw CameraException(error, cause: e);
    }
  }

  /// Get barcode scanning statistics
  Map<String, dynamic> get barcodeStatistics => _barcodeController.statistics;

  /// Clear barcode detection cache
  void clearBarcodeCache() { _barcodeController.clearCache(); }

  /// Get supported barcode formats
  Set<BarcodeFormat> get supportedBarcodeFormats => _barcodeController.supportedFormats;

  // --- Private Helper Methods ---

  /// Update the controller state and notify listeners
void _updateState(CameraState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateStreamController.add(_state);
    notifyListeners();
    debugPrint('Camera state changed to: $_state');
  }

  /// Set error message and optionally update state
  void _setError(String error, [CameraState? errorState]) {
    _lastError = error;
    _errorStreamController.add(error);
    if (errorState != null) _updateState(errorState);
    debugPrint('Camera error: $error');
  }



  /// Validate that the controller is in one of the allowed states
  void _validateState(List<CameraState> allowedStates) {
    if (!allowedStates.contains(_state)) {
      throw CameraException('Invalid state for operation: $_state. Allowed states: $allowedStates');
    }
  }

  /// Disposes the controller and releases all associated resources.
  @override
 void dispose() {
    if (_state == CameraState.disposed) return;
    debugPrint('Disposing CameraController...');
    try {
      _stopCurrentModeOperations();
      (_nativeController as dynamic)?.dispose(); // INTEGRATION: Dispose the native controller if attached
    } catch (e) {
      debugPrint('Error during dispose: $e');
    }
    _barcodeController.dispose();
    _imageAnalyzerService.dispose();
    _stateStreamController.close();
    _errorStreamController.close();
    _updateState(CameraState.disposed);
    super.dispose();
    debugPrint('CameraController disposed.');
  }
}