import 'package:flutter/material.dart';
import 'package:multi_camera_scanner/multi_camera_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Camera Scanner Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CameraExamplePage(),
    );
  }
}

class CameraExamplePage extends StatefulWidget {
  const CameraExamplePage({super.key});

  @override
  State<CameraExamplePage> createState() => _CameraExamplePageState();
}

class _CameraExamplePageState extends State<CameraExamplePage> {
  late CameraController _cameraController;
  CameraMode _currentMode = CameraMode.photo;
  final List<BarcodeResult> _detectedBarcodes = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      config: CameraConfig(
        initialMode: _currentMode,
        resolution: CameraResolution.high,
        enableAudio: true,
        flashMode: FlashMode.auto,
        maxVideoDuration: const Duration(seconds: 30),
        videoFrameRate: 30,
        barcodeDetectionInterval: const Duration(milliseconds: 500),
        detectMultipleBarcodes: true,
        minBarcodeConfidence: 0.7,
        autoFocus: true,
        preferredCameraPosition: CameraPosition.back,
      ),
    );

    try {
      await _cameraController.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Failed to initialize camera: $e');
      _showErrorSnackBar('Failed to initialize camera: $e');
    }
  }

  Future<void> _switchMode(CameraMode mode) async {
    try {
      await _cameraController.setMode(mode);
      setState(() {
        _currentMode = mode;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to switch mode: $e');
    }
  }

  void _onBarcodeDetected(BarcodeResult barcode) {
    setState(() {
      _detectedBarcodes.add(barcode);
      // Keep only last 10 barcodes
      if (_detectedBarcodes.length > 10) {
        _detectedBarcodes.removeAt(0);
      }
    });
  }

  void _clearBarcodes() {
    setState(() {
      _detectedBarcodes.clear();
    });
    _cameraController.clearBarcodeCache();
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

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi Camera Scanner Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Mode selector
          _buildModeSelector(),
          
          // Camera preview
          Expanded(
            child: _isInitialized
                ? CameraPreviewWidget(
                    controller: _cameraController,
                    config: const CameraPreviewConfig(
                      showControls: true,
                      showLoadingIndicator: true,
                    ),
                    onBarcodeDetected: _onBarcodeDetected,
                  )
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          ),
          
          // Barcode results
          if (_currentMode == CameraMode.barcode) _buildBarcodeResults(),
          
          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModeButton(CameraMode.photo, 'Photo', Icons.camera_alt),
          _buildModeButton(CameraMode.video, 'Video', Icons.videocam),
          _buildModeButton(CameraMode.barcode, 'Barcode', Icons.qr_code_scanner),
        ],
      ),
    );
  }

  Widget _buildModeButton(CameraMode mode, String label, IconData icon) {
    final isSelected = _currentMode == mode;
    return ElevatedButton.icon(
      onPressed: isSelected ? null : () => _switchMode(mode),
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : null,
        foregroundColor: isSelected ? Colors.white : null,
      ),
    );
  }

  Widget _buildBarcodeResults() {
    if (_detectedBarcodes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'No barcodes detected yet. Point camera at a barcode or QR code.',
          textAlign: TextAlign.center,
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detected Barcodes (${_detectedBarcodes.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: _clearBarcodes,
                child: const Text('Clear'),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _detectedBarcodes.length,
              itemBuilder: (context, index) {
                final barcode = _detectedBarcodes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      _getBarcodeIcon(barcode.format),
                      color: Colors.blue,
                    ),
                    title: Text(
                      barcode.value,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${barcode.format.displayName} • ${_formatTimestamp(barcode.timestamp)}',
                    ),
                    trailing: Text(
                      '${(barcode.confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: barcode.confidence > 0.8 ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_currentMode == CameraMode.photo)
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final path = await _cameraController.takePicture();
                  _showSuccessSnackBar('Picture taken: $path');
                } catch (e) {
                  _showErrorSnackBar('Failed to take picture: $e');
                }
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Picture'),
            ),
          if (_currentMode == CameraMode.video)
            ElevatedButton.icon(
              onPressed: _cameraController.isRecordingVideo
                  ? () async {
                      try {
                        final path = await _cameraController.stopVideo();
                        _showSuccessSnackBar('Video recorded: $path');
                      } catch (e) {
                        _showErrorSnackBar('Failed to stop video: $e');
                      }
                    }
                  : () async {
                      try {
                        await _cameraController.startVideo();
                        _showSuccessSnackBar('Video recording started');
                      } catch (e) {
                        _showErrorSnackBar('Failed to start video: $e');
                      }
                    },
              icon: Icon(_cameraController.isRecordingVideo ? Icons.stop : Icons.videocam),
              label: Text(_cameraController.isRecordingVideo ? 'Stop Video' : 'Start Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cameraController.isRecordingVideo ? Colors.red : null,
                foregroundColor: _cameraController.isRecordingVideo ? Colors.white : null,
              ),
            ),
          if (_currentMode == CameraMode.barcode)
            ElevatedButton.icon(
              onPressed: () async {
                // TODO: Implement image analysis from gallery
                _showInfoSnackBar('Image analysis coming in next iteration');
              },
              icon: const Icon(Icons.photo_library),
              label: const Text('Analyze Image'),
            ),
        ],
      ),
    );
  }

  IconData _getBarcodeIcon(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.qrCode:
        return Icons.qr_code;
      case BarcodeFormat.dataMatrix:
        return Icons.grid_on;
      case BarcodeFormat.code128:
      case BarcodeFormat.code39:
        return Icons.qr_code_2;
      case BarcodeFormat.ean13:
      case BarcodeFormat.ean8:
      case BarcodeFormat.upcA:
      case BarcodeFormat.upcE:
        return Icons.straighten;
      default:
        return Icons.qr_code_scanner;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showInfoSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
