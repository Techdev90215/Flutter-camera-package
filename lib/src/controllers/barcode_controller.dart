// lib/src/controllers/barcode_controller.dart

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:multi_camera_scanner/src/models/barcode_result.dart';
import 'package:multi_camera_scanner/src/models/camera_config.dart';
import 'package:multi_camera_scanner/src/services/barcode_detector_service.dart';

/// Manages the state and logic specifically for barcode scanning.
///
/// This controller is intended to be used internally by the main `CameraController`
/// to delegate barcode-related tasks, keeping the main controller cleaner.
class BarcodeController {
  final CameraConfig _config;
  final BarcodeDetectorService _detectorService;

  /// The stream that outputs lists of detected barcodes.
  final _barcodeStreamController = StreamController<List<BarcodeResult>>.broadcast();
  Stream<List<BarcodeResult>> get stream => _barcodeStreamController.stream;

  /// Cache of recently detected barcodes to avoid duplicates
  final _recentBarcodes = Queue<BarcodeResult>();
  static const int _maxRecentBarcodes = 10;

  /// Whether barcode detection is currently active
  bool _isScanning = false;
  
  /// Statistics for debugging and optimization
  int _totalFramesProcessed = 0;
  int _totalBarcodesDetected = 0;
  DateTime? _scanStartTime;

  BarcodeController({required CameraConfig config})
      : _config = config,
        _detectorService = BarcodeDetectorService(config: config);

  /// Initialize the barcode controller
  Future<void> initialize() async {
    try {
      await _detectorService.initialize();
      debugPrint('BarcodeController initialized');
    } catch (e) {
      debugPrint('Failed to initialize BarcodeController: $e');
      rethrow;
    }
  }

  /// Start barcode scanning
  void startScanning() {
    if (_isScanning) return;
    
    _isScanning = true;
    _scanStartTime = DateTime.now();
    _detectorService.startDetection();
    
    debugPrint('Barcode scanning started');
  }

  /// Stop barcode scanning
  void stopScanning() {
    if (!_isScanning) return;
    
    _isScanning = false;
    _detectorService.stopDetection();
    
    if (_scanStartTime != null) {
      final duration = DateTime.now().difference(_scanStartTime!);
      debugPrint('Barcode scanning stopped. Duration: ${duration.inSeconds}s, '
          'Frames: $_totalFramesProcessed, Barcodes: $_totalBarcodesDetected');
    }
  }

  /// Whether barcode scanning is currently active
  bool get isScanning => _isScanning;

  /// Get scanning statistics
  Map<String, dynamic> get statistics => {
    'isScanning': _isScanning,
    'totalFramesProcessed': _totalFramesProcessed,
    'totalBarcodesDetected': _totalBarcodesDetected,
    'scanDuration': _scanStartTime != null 
        ? DateTime.now().difference(_scanStartTime!).inMilliseconds 
        : null,
    'averageBarcodesPerSecond': _scanStartTime != null && _totalBarcodesDetected > 0
        ? _totalBarcodesDetected / (DateTime.now().difference(_scanStartTime!).inSeconds)
        : 0,
  };

  /// Process frame with raw bytes and dimensions
  Future<List<BarcodeResult>> processFrame(
    Uint8List bytes,
    int width,
    int height,
    int rotation,
  ) async {
    if (!_isScanning) return [];
    
    try {
      _totalFramesProcessed++;
      
      // Create a CameraFrame object using the service's class
      final frame = CameraFrame(
        bytes: bytes,
        width: width,
        height: height,
        format: 'yuv420', // Default format, adjust as needed
        rotation: rotation,
      );
      
      final results = await _detectorService.processCameraFrame(frame);
      
      if (results.isNotEmpty) {
        _totalBarcodesDetected += results.length;
        return results;
      }
      
      return [];
    } catch (e) {
      debugPrint('Error processing barcode frame: $e');
      return [];
    }
  }

  /// Update detected barcodes and push to stream
  void updateDetectedBarcodes(List<BarcodeResult> barcodes) {
    if (barcodes.isNotEmpty) {
      final newResults = _filterDuplicates(barcodes);
      if (newResults.isNotEmpty) {
        _addToRecentCache(newResults);
        _barcodeStreamController.add(newResults);
      }
    }
  }

  /// Filter out recently detected duplicate barcodes
  List<BarcodeResult> _filterDuplicates(List<BarcodeResult> newResults) {
    if (!_config.detectMultipleBarcodes && newResults.isNotEmpty) {
      // If single barcode mode, take the first one and check against recent cache
      final barcode = newResults.first;
      if (_isDuplicateBarcode(barcode)) return [];
      return [barcode];
    }

    // Filter out duplicates for multiple barcode mode
    return newResults.where((barcode) => !_isDuplicateBarcode(barcode)).toList();
  }

  /// Check if a barcode was recently detected (to avoid spam)
  bool _isDuplicateBarcode(BarcodeResult barcode) {
    const duplicateThreshold = Duration(milliseconds: 500); // Adjust as needed
    final now = DateTime.now();
    
    return _recentBarcodes.any((recent) => 
      recent.value == barcode.value && 
      recent.format == barcode.format &&
      now.difference(recent.timestamp) < duplicateThreshold
    );
  }

  /// Add barcodes to recent cache for duplicate detection
  void _addToRecentCache(List<BarcodeResult> barcodes) {
    for (final barcode in barcodes) {
      _recentBarcodes.add(barcode.copyWith(timestamp: DateTime.now()));
      
      // Keep cache size reasonable
      while (_recentBarcodes.length > _maxRecentBarcodes) {
        _recentBarcodes.removeFirst();
      }
    }
  }

  /// Clear the recent barcodes cache
  void clearCache() {
    _recentBarcodes.clear();
    debugPrint('Barcode cache cleared');
  }

  /// Get the list of supported barcode formats
  Set<BarcodeFormat> get supportedFormats => _detectorService.supportedFormats;

  /// Check if a specific format is supported
  bool supportsFormat(BarcodeFormat format) => _detectorService.supportsFormat(format);

  /// Disposes the controller and its resources.
  void dispose() {
    stopScanning();
    _barcodeStreamController.close();
    _detectorService.dispose();
    _recentBarcodes.clear();
    debugPrint('BarcodeController disposed.');
  }
}

/// Exception thrown when barcode processing fails
class BarcodeProcessingException implements Exception {
  final String message;
  final Object? cause;

  const BarcodeProcessingException(this.message, [this.cause]);

  @override
  String toString() => 'BarcodeProcessingException: $message${cause != null ? ' (${cause.toString()})' : ''}';
}