// lib/src/widgets/barcode_overlay_widget.dart

import 'package:flutter/material.dart';
import 'package:multi_camera_scanner/src/models/barcode_result.dart';

/// Configuration for barcode overlay appearance
class BarcodeOverlayConfig {
  /// Color of the bounding box stroke
  final Color boundingBoxColor;
  
  /// Width of the bounding box stroke
  final double boundingBoxStrokeWidth;
  
  /// Style of the bounding box stroke
  final PaintingStyle boundingBoxStyle;
  
  /// Whether to show corner indicators
  final bool showCorners;
  
  /// Color of corner indicators
  final Color cornerColor;
  
  /// Size of corner indicators
  final double cornerSize;
  
  /// Whether to show barcode value text
  final bool showValue;
  
  /// Text style for barcode value
  final TextStyle? valueTextStyle;
  
  /// Background color for value text
  final Color? valueBackgroundColor;
  
  /// Whether to animate the overlay
  final bool animated;

  const BarcodeOverlayConfig({
    this.boundingBoxColor = Colors.red,
    this.boundingBoxStrokeWidth = 3.0,
    this.boundingBoxStyle = PaintingStyle.stroke,
    this.showCorners = true,
    this.cornerColor = Colors.green,
    this.cornerSize = 10.0,
    this.showValue = true,
    this.valueTextStyle,
    this.valueBackgroundColor = Colors.black54,
    this.animated = true,
  });
}

/// A widget that draws an overlay on top of the camera preview.
///
/// It is responsible for painting the bounding boxes of detected barcodes.
class BarcodeOverlayWidget extends StatefulWidget {
  final List<BarcodeResult> barcodes;
  final BarcodeOverlayConfig config;
  final Size? previewSize;
  final ValueChanged<BarcodeResult>? onBarcodeTap;

  const BarcodeOverlayWidget({
    super.key,
    required this.barcodes,
    this.config = const BarcodeOverlayConfig(),
    this.previewSize,
    this.onBarcodeTap,
  });

  @override
  State<BarcodeOverlayWidget> createState() => _BarcodeOverlayWidgetState();
}

class _BarcodeOverlayWidgetState extends State<BarcodeOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    if (widget.config.animated) {
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      
      _pulseAnimation = Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));
      
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    if (widget.config.animated) {
      _animationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.barcodes.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget overlay = CustomPaint(
      painter: _BarcodeOverlayPainter(
        barcodes: widget.barcodes,
        config: widget.config,
        previewSize: widget.previewSize,
        animationValue: widget.config.animated ? _pulseAnimation.value : 1.0,
      ),
      size: Size.infinite,
    );

    // Add tap detection if callback is provided
    if (widget.onBarcodeTap != null) {
      overlay = GestureDetector(
        onTapUp: (details) => _handleTap(details.localPosition),
        child: overlay,
      );
    }

    return overlay;
  }

  void _handleTap(Offset tapPosition) {
    if (widget.onBarcodeTap == null) return;

    // Find which barcode was tapped (if any)
    for (final barcode in widget.barcodes) {
      if (barcode.boundingBox?.contains(tapPosition) == true) {
        widget.onBarcodeTap!(barcode);
        break;
      }
    }
  }
}

class _BarcodeOverlayPainter extends CustomPainter {
  final List<BarcodeResult> barcodes;
  final BarcodeOverlayConfig config;
  final Size? previewSize;
  final double animationValue;

  _BarcodeOverlayPainter({
    required this.barcodes,
    required this.config,
    this.previewSize,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final barcode in barcodes) {
      _paintBarcode(canvas, size, barcode);
    }
  }

  void _paintBarcode(Canvas canvas, Size size, BarcodeResult barcode) {
    final boundingBox = barcode.boundingBox;
    if (boundingBox == null) return;

    // Scale bounding box if preview size is different from overlay size
    final scaledRect = _scaleRect(boundingBox, size);

    // Draw bounding box
    _drawBoundingBox(canvas, scaledRect);

    // Draw corners
    if (config.showCorners) {
      _drawCorners(canvas, scaledRect);
    }

    // Draw value text
    if (config.showValue) {
      _drawValueText(canvas, scaledRect, barcode.value);
    }
  }

  Rect _scaleRect(Rect originalRect, Size overlaySize) {
    if (previewSize == null) return originalRect;

    final scaleX = overlaySize.width / previewSize!.width;
    final scaleY = overlaySize.height / previewSize!.height;

    return Rect.fromLTRB(
      originalRect.left * scaleX,
      originalRect.top * scaleY,
      originalRect.right * scaleX,
      originalRect.bottom * scaleY,
    );
  }

  void _drawBoundingBox(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = config.boundingBoxColor.withOpacity(animationValue)
      ..style = config.boundingBoxStyle
      ..strokeWidth = config.boundingBoxStrokeWidth;

    canvas.drawRect(rect, paint);
  }

 void _drawCorners(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = config.cornerColor.withOpacity(animationValue)
      ..style = PaintingStyle.fill;

    final cornerSize = config.cornerSize;
    
    // Top-left corner
    canvas.drawCircle(rect.topLeft, cornerSize / 2, paint);
    
    // Top-right corner
    canvas.drawCircle(rect.topRight, cornerSize / 2, paint);
    
    // Bottom-left corner
    canvas.drawCircle(rect.bottomLeft, cornerSize / 2, paint);
    
    // Bottom-right corner
    canvas.drawCircle(rect.bottomRight, cornerSize / 2, paint);
  }

    void _drawValueText(Canvas canvas, Rect rect, String value) {
    final textStyle = config.valueTextStyle ?? const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: value, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Position text above the bounding box
    final textOffset = Offset(
      rect.left,
      rect.top - textPainter.height - 5,
    );
    
    // Draw background if specified
    if (config.valueBackgroundColor != null) {
      final backgroundRect = Rect.fromLTWH(
        textOffset.dx - 4,
        textOffset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      
      final backgroundPaint = Paint()
        ..color = config.valueBackgroundColor!.withOpacity(0.8 * animationValue);
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
        backgroundPaint,
      );
    }
    
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _BarcodeOverlayPainter oldDelegate) {
    return oldDelegate.barcodes != barcodes ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.previewSize != previewSize;
  }
}