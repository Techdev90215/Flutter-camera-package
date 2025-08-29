// lib/src/widgets/camera_preview_widget.dart

import 'dart:async';
import 'package:camerawesome/camerawesome_plugin.dart' as awesome hide CameraState;
import 'package:flutter/material.dart';
import 'package:multi_camera_scanner/src/controllers/camera_controller.dart';
import 'package:multi_camera_scanner/src/models/barcode_result.dart';
import 'package:multi_camera_scanner/src/models/camera_mode.dart';
import 'package:multi_camera_scanner/src/models/camera_config.dart';
import 'package:multi_camera_scanner/src/widgets/barcode_overlay_widget.dart';

/// Configuration for camera preview widget
class CameraPreviewConfig {
  /// Whether to show loading indicator during initialization
  final bool showLoadingIndicator;
  
  /// Loading indicator widget
  final Widget? loadingIndicator;
  
  /// Error widget builder
  final Widget Function(String error)? errorBuilder;
  
  /// Barcode overlay configuration
  final BarcodeOverlayConfig barcodeOverlayConfig;
  
  /// Whether to show camera controls overlay
  final bool showControls;
  
  /// Background color when camera is not ready
  final Color backgroundColor;

  const CameraPreviewConfig({
    this.showLoadingIndicator = true,
    this.loadingIndicator,
    this.errorBuilder,
    this.barcodeOverlayConfig = const BarcodeOverlayConfig(),
    this.showControls = false,
    this.backgroundColor = Colors.black,
  });
}

/// The main widget that displays the camera feed and overlays.
class CameraPreviewWidget extends StatefulWidget {
  final CameraController controller;
  final CameraPreviewConfig config;
  final ValueChanged<BarcodeResult>? onBarcodeDetected;
  final VoidCallback? onTap;

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    this.config = const CameraPreviewConfig(),
    this.onBarcodeDetected,
    this.onTap,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  late StreamSubscription<List<BarcodeResult>> _barcodeSubscription;
  late StreamSubscription<CameraState> _stateSubscription;
  late StreamSubscription<String?> _errorSubscription;
  
  List<BarcodeResult> _detectedBarcodes = [];
  CameraState _cameraState = CameraState.uninitialized;
  String? _errorMessage;
  dynamic _awesomeState;

  FlashMode _currentFlashMode = FlashMode.auto;
  final _flashModes = [FlashMode.auto, FlashMode.on, FlashMode.off, FlashMode.torch];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _setupListeners();
  }

  @override
  void dispose() {
    _barcodeSubscription.cancel();
    _stateSubscription.cancel();
    _errorSubscription.cancel();
    super.dispose();
  }

  void _setupListeners() {
    // Listen to barcode detections
    _barcodeSubscription = widget.controller.barcodeStream.listen((barcodes) {
      setState(() {
        _detectedBarcodes = barcodes;
      });
      
      // Notify parent widget
      if (widget.onBarcodeDetected != null && barcodes.isNotEmpty) {
        widget.onBarcodeDetected!(barcodes.first);
      }
    });

    // Listen to camera state changes
    _stateSubscription = widget.controller.stateStream.listen((state) {
      setState(() {
        _cameraState = state;
      });
    });

    // Listen to errors
    _errorSubscription = widget.controller.errorStream.listen((error) {
      setState(() {
        _errorMessage = error;
      });
    });
  }

  Future<void> _initializeCamera() async {
    if (!widget.controller.isInitialized) {
      try {
        await widget.controller.initialize();
      } catch (e) {
        debugPrint('Failed to initialize camera: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // INTEGRATION: Use ListenableBuilder to react to controller changes (like mode switches)
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        return Container(
          color: widget.config.backgroundColor,
          child: _buildContent(),
        );
      },
    );
  }

  Widget _buildContent() {
    // Show error state
    if (_errorMessage != null) {
      return _buildErrorWidget(_errorMessage!);
    }

    // Show loading state
    if (_cameraState == CameraState.initializing) {
      return _buildLoadingWidget();
    }

    // Show camera preview
    if (widget.controller.isInitialized) {
      return _buildCameraPreview();
    }

    // Show uninitialized state
    return _buildUninitializedWidget();
  }

  Widget _buildErrorWidget(String error) {
    if (widget.config.errorBuilder != null) {
      return widget.config.errorBuilder!(error);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Camera Error',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeCamera,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    if (!widget.config.showLoadingIndicator) {
      return const SizedBox.shrink();
    }

    if (widget.config.loadingIndicator != null) {
      return Center(child: widget.config.loadingIndicator!);
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Initializing Camera...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildUninitializedWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Camera Not Ready',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap to initialize camera',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeCamera,
            child: const Text('Initialize Camera'),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camerawesome preview with proper configs; attach native state to our controller
          awesome.CameraAwesomeBuilder.custom(
            saveConfig: awesome.SaveConfig.photoAndVideo(
              initialCaptureMode: widget.controller.currentMode == CameraMode.video
                  ? awesome.CaptureMode.video
                  : awesome.CaptureMode.photo,
            ),
            builder: (cameraState, preview) {
              _awesomeState = cameraState;
              widget.controller.attachNativeController(cameraState);
              return const SizedBox.shrink();
            },
            onMediaCaptureEvent: (event) {
              widget.controller.handleMediaCaptureEvent(event);
            },
          ),
          
          if (widget.controller.currentMode == CameraMode.barcode)
            BarcodeOverlayWidget(
              barcodes: _detectedBarcodes,
              // config: widget.config.barcodeOverlayConfig, // Assuming this is on your BarcodeOverlayWidget
              // onBarcodeTap: widget.onBarcodeDetected,
            ),
          
          // Use a ListenableBuilder to show/hide controls based on controller state
          ListenableBuilder(
            listenable: widget.controller,
            builder: (context, child) {
              if (widget.config.showControls) {
                return _buildControlsOverlay();
              }
              return const SizedBox.shrink();
            }
          ),
        ],
      ),
    );
  }

  // Placeholder preview removed (unused)

  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: _buildModeSpecificControls(),
      ),
    );
  }

  Widget _buildModeSpecificControls() {
    switch (widget.controller.currentMode) {
      case CameraMode.photo:
        return _buildPhotoControls();
      case CameraMode.video:
        return _buildVideoControls();
      case CameraMode.barcode:
        return _buildBarcodeControls();
    }
  }

  Widget _buildPhotoControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: widget.controller.switchCamera,
          icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32),
        ),
        FloatingActionButton(
          onPressed: _takePicture,
          backgroundColor: Colors.white,
          child: const Icon(Icons.camera_alt, color: Colors.black, size: 32),
        ),
        IconButton(
          // INTEGRATION: Implement flash toggle
          onPressed: _toggleFlash,
          icon: Icon(_flashIcon(_currentFlashMode), color: Colors.white, size: 32),
        ),
      ],
    );
  }

  Widget _buildVideoControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: widget.controller.switchCamera,
          icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
        ),
        FloatingActionButton(
          onPressed: widget.controller.isRecordingVideo ? _stopVideo : _startVideo,
          backgroundColor: widget.controller.isRecordingVideo ? Colors.red : Colors.white,
          child: Icon(
            widget.controller.isRecordingVideo ? Icons.stop : Icons.videocam,
            color: widget.controller.isRecordingVideo ? Colors.white : Colors.red,
          ),
        ),
        // Show recording duration
        if (widget.controller.isRecordingVideo)
          StreamBuilder<Duration?>(
            stream: Stream.periodic(const Duration(seconds: 1), 
              (_) => widget.controller.videoRecordingDuration),
            builder: (context, snapshot) {
              final duration = snapshot.data;
              if (duration == null) return const SizedBox.shrink();
              
              return Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              );
            },
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildBarcodeControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ... (status text remains the same)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: widget.controller.switchCamera,
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            ),
            IconButton(
              onPressed: widget.controller.clearBarcodeCache,
              icon: const Icon(Icons.clear_all, color: Colors.white),
            ),
            IconButton(
              // INTEGRATION: Implement flash toggle
              onPressed: _toggleFlash,
              icon: Icon(_flashIcon(_currentFlashMode), color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

    // --- Action Methods ---

  Future<void> _takePicture() async {
    try {
      final imagePath = await widget.controller.takePicture();
      // INTEGRATION: Handle successful photo capture with a snackbar.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo saved to: $imagePath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to take picture: $e');
      _showErrorSnackBar('Failed to take picture: ${e.toString()}');
    }
  }
  

  Future<void> _startVideo() async {
    try {
      // Ensure we are in video mode, then start from Camerawesome state
      if (widget.controller.currentMode != CameraMode.video) {
        await widget.controller.setMode(CameraMode.video);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      bool started = false;
      try {
        _awesomeState.when(
          onPreparingCamera: (_) {},
          onPhotoMode: (s) { try { s.toVideoMode(); } catch (_) {} },
          onVideoMode: (s) { s.startRecording(); started = true; },
          onVideoRecordingMode: (_) { started = true; },
        );
      } catch (_) {}
      if (!started) {
        try { _awesomeState.startRecording(); started = true; } catch (_) {}
      }
      if (!started) {
        await widget.controller.startVideo();
      }
      debugPrint('Video recording started');
    } catch (e) {
      debugPrint('Failed to start video: $e');
      _showErrorSnackBar('Failed to start video: $e');
    }
  }

 Future<void> _stopVideo() async {
    try {
      String? path;
      bool stopped = false;
      try {
        _awesomeState.when(
          onPreparingCamera: (_) {},
          onPhotoMode: (_) {},
          onVideoMode: (_) {},
          onVideoRecordingMode: (s) { s.stopRecording(); stopped = true; },
        );
      } catch (_) {}
      if (!stopped) {
        try { _awesomeState.stopRecording(); stopped = true; } catch (_) {}
      }
      final videoPath = stopped ? await widget.controller.stopVideo() : await widget.controller.stopVideo();
      // INTEGRATION: Handle successful video capture with a snackbar.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video saved to: $videoPath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to stop video: $e');
      _showErrorSnackBar('Failed to stop video: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

   void _toggleFlash() {
    final currentIndex = _flashModes.indexOf(_currentFlashMode);
    final nextIndex = (currentIndex + 1) % _flashModes.length;
    final nextMode = _flashModes[nextIndex];
    
    widget.controller.setFlashMode(nextMode);
    setState(() {
      _currentFlashMode = nextMode;
    });
  }

  IconData _flashIcon(FlashMode mode) {
    switch (mode) {
      case FlashMode.on:
      case FlashMode.torch:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}