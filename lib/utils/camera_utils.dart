import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:flutter/foundation.dart';

class CameraUtils {
  static InputImage? convertCameraImageToInputImage(
      CameraImage image, CameraDescription camera) {
    final bytes = _getBytes(image);
    if (bytes == null) return null;

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());
    final imageRotation = _mapRotation(camera.sensorOrientation);

    // On Android, we force NV21 format because that's what we converted to (or what's expected)
    final inputImageFormat = defaultTargetPlatform == TargetPlatform.android
        ? InputImageFormat.nv21
        : _mapFormat(image.format.raw);

    if (inputImageFormat == null) return null;

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  static Uint8List? _getBytes(CameraImage image) {
    if (defaultTargetPlatform == TargetPlatform.android &&
        image.format.group == ImageFormatGroup.yuv420) {
      // Converting YUV420 to NV21
      // YUV420: 3 planes (Y, U, V)
      // NV21: Y plane followed by interleaved V/U plane

      final int width = image.width;
      final int height = image.height;

      // Y Plane
      final Plane yPlane = image.planes[0];
      // U Plane
      final Plane uPlane = image.planes[1];
      // V Plane
      final Plane vPlane = image.planes[2];

      final Uint8List yBuffer = yPlane.bytes;
      final Uint8List uBuffer = uPlane.bytes;
      final Uint8List vBuffer = vPlane.bytes;

      int numPixels = (width * height * 1.5).toInt();
      List<int> nv21 = List<int>.filled(numPixels, 0);

      // Copy Y
      // Optimized: Assuming yPixelStride is 1
      int idY = 0;
      for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
          nv21[idY++] = yBuffer[i * yPlane.bytesPerRow + j];
        }
      }

      // Copy UV (Interleaved V then U)
      // NV21 expects V then U
      int idUV = width * height;
      final int uvHeight = height ~/ 2;
      final int uvWidth = width ~/ 2;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      for (int i = 0; i < uvHeight; i++) {
        for (int j = 0; j < uvWidth; j++) {
          final int uvIndex = i * uvRowStride + (j * uvPixelStride);
          // V first
          nv21[idUV++] = vBuffer[uvIndex];
          // U second
          nv21[idUV++] = uBuffer[uvIndex];
        }
      }

      return Uint8List.fromList(nv21);
    }

    // Fallback / iOS
    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  static InputImageRotation _mapRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  static InputImageFormat? _mapFormat(dynamic rawFormat) {
    // iOS (bgra8888 is 1111970369)
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (rawFormat == 1111970369) return InputImageFormat.bgra8888;
    }
    return null;
  }
}
