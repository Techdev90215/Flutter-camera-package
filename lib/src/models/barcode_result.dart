// lib/src/models/barcode_result.dart

import 'dart:ui';
import 'package:flutter/foundation.dart';

enum BarcodeFormat {
  ///QR Code format
  qrCode,
  ///Data Matrix format
  dataMatrix,
  ///Code 128 format
  code128,
  ///Code 39 format
  code39,
  ///EAN-13 format
  ean13,
  ///EAN-8 format
  ean8,
  ///UPC-A format
  upcA,
  ///UPC-E format
  upcE,
  ///PDF417 format
  pdf417,
  ///Aztec format
  aztec,
  ///ITF format
  itf,
  ///Unknown format
  unknown,
}

/// Extension to convert string format to BarcodeFormat enum
extension BarcodeFormatExtension on BarcodeFormat {
  static BarcodeFormat fromString(String format) {
    switch (format.toLowerCase()) {
      case 'qr_code':
      case 'qrcode':
        return BarcodeFormat.qrCode;
      case 'data_matrix':
      case 'datamatrix':
        return BarcodeFormat.dataMatrix;
      case 'code_128':
      case 'code128':
        return BarcodeFormat.code128;
      case 'code_39':
      case 'code39':
        return BarcodeFormat.code39;
      case 'ean_13':
      case 'ean13':
        return BarcodeFormat.ean13;
      case 'ean_8':
      case 'ean8':
        return BarcodeFormat.ean8;
      case 'upc_a':
      case 'upca':
        return BarcodeFormat.upcA;
      case 'upc_e':
      case 'upce':
        return BarcodeFormat.upcE;
      case 'pdf417':
        return BarcodeFormat.pdf417;
      case 'aztec':
        return BarcodeFormat.aztec;
      case 'itf':
        return BarcodeFormat.itf;
      default:
        return BarcodeFormat.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.upcA:
        return 'UPC-A';
      case BarcodeFormat.upcE:
        return 'UPC-E';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.aztec:
        return 'Aztec';
      case BarcodeFormat.itf:
        return 'ITF';
      case BarcodeFormat.unknown:
        return 'Unknown';
    }
  }
}

/// Represents a single detected barcode, containing its value and location.
@immutable
class BarcodeResult {
  /// The raw string value decoded from the barcode.
  final String value;

  /// The format of the barcode (e.g., QRCode, DataMatrix).
  final BarcodeFormat format;

  /// The bounding box that encloses the detected barcode in the preview image.
  ///
  /// This can be null if the detector does not provide a bounding box.
  final Rect? boundingBox;

  /// Corner points of the detected barcode (useful for drawing polygons)
  final List<Offset>? cornerPoints;

  /// Timestamp when this barcode was detected
  final DateTime timestamp;

  /// Confidence score of the detection (0.0 to 1.0)
  final double confidence;

  BarcodeResult({
    required this.value,
    required this.format,
    this.boundingBox,
    this.cornerPoints,
    DateTime? timestamp,
    this.confidence = 1.0,
  }) : timestamp = timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Creates a copy of this BarcodeResult with some fields replaced
  BarcodeResult copyWith({
    String? value,
    BarcodeFormat? format,
    Rect? boundingBox,
    List<Offset>? cornerPoints,
    DateTime? timestamp,
    double? confidence,
  }) {
    return BarcodeResult(
      value: value ?? this.value,
      format: format ?? this.format,
      boundingBox: boundingBox ?? this.boundingBox,
      cornerPoints: cornerPoints ?? this.cornerPoints,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
    );
  }

  /// Convert to JSON map for serialization
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'format': format.name,
      'boundingBox': boundingBox != null
          ? {
              'left': boundingBox!.left,
              'top': boundingBox!.top,
              'right': boundingBox!.right,
              'bottom': boundingBox!.bottom,
            }
          : null,
      'cornerPoints': cornerPoints?.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'confidence': confidence,
    };
  }

  /// Create from JSON map
  factory BarcodeResult.fromJson(Map<String, dynamic> json) {
    final boundingBoxData = json['boundingBox'] as Map<String, dynamic>?;
    final cornerPointsData = json['cornerPoints'] as List<dynamic>?;

    return BarcodeResult(
      value: json['value'] as String,
      format: BarcodeFormatExtension.fromString(json['format'] as String),
      boundingBox: boundingBoxData != null
          ? Rect.fromLTRB(
              (boundingBoxData['left'] as num).toDouble(),
              (boundingBoxData['top'] as num).toDouble(),
              (boundingBoxData['right'] as num).toDouble(),
              (boundingBoxData['bottom'] as num).toDouble(),
            )
          : null,
      cornerPoints: cornerPointsData
          ?.map((p) => Offset(
              (p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
          .toList(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BarcodeResult &&
        other.value == value &&
        other.format == format &&
        other.boundingBox == boundingBox &&
        listEquals(other.cornerPoints, cornerPoints) &&
        other.timestamp == timestamp &&
        other.confidence == confidence;
  }

  @override
  int get hashCode {
    return Object.hash(
      value,
      format,
      boundingBox,
      cornerPoints,
      timestamp,
      confidence,
    );
  }

  @override
  String toString() {
    return 'BarcodeResult(value: $value, format: ${format.displayName}, boundingBox: $boundingBox, confidence: $confidence)';
  }
}