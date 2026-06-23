import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'creature_scanner_errors.dart';

abstract class ScannerImageCompressor {
  Future<XFile> compressFile(XFile file);
}

class FlutterScannerImageCompressor implements ScannerImageCompressor {
  static const int maxImageBytes = 1500000;
  static const int maxDimension = 1600;
  static const int jpegQuality = 78;

  const FlutterScannerImageCompressor();

  @override
  Future<XFile> compressFile(XFile file) async {
    final inputBytes = await file.readAsBytes();
    if (inputBytes.isEmpty) {
      throw const CreatureScannerException(
        CreatureScannerErrorType.invalidImage,
      );
    }

    final compressed = await FlutterImageCompress.compressWithList(
      inputBytes,
      quality: jpegQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
      autoCorrectionAngle: true,
    );

    Uint8List outputBytes;
    if (compressed.length <= maxImageBytes) {
      outputBytes = Uint8List.fromList(compressed);
    } else {
      final resized = await FlutterImageCompress.compressWithList(
        inputBytes,
        minHeight: maxDimension,
        minWidth: maxDimension,
        quality: jpegQuality,
        format: CompressFormat.jpeg,
        keepExif: false,
        autoCorrectionAngle: true,
      );
      outputBytes = Uint8List.fromList(resized);
    }

    if (outputBytes.isEmpty) {
      throw const CreatureScannerException(
        CreatureScannerErrorType.invalidImage,
      );
    }
    if (outputBytes.length > maxImageBytes) {
      throw const CreatureScannerException(
        CreatureScannerErrorType.payloadTooLarge,
      );
    }

    final directory = await Directory.systemTemp.createTemp('aphidex_scanner_');
    final outputPath =
        '${directory.path}${Platform.pathSeparator}scan_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final tempFile = File(outputPath);
    await tempFile.writeAsBytes(outputBytes, flush: true);
    return XFile(
      tempFile.path,
      mimeType: 'image/jpeg',
      name: tempFile.uri.pathSegments.last,
    );
  }
}

void deleteTemporaryScannerFile(XFile compressedFile, XFile originalFile) {
  if (compressedFile.path == originalFile.path || compressedFile.path.isEmpty) {
    return;
  }
  unawaited(
    File(
      compressedFile.path,
    ).delete().then((_) => null).catchError((_) => null),
  );
}
