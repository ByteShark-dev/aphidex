import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/player_character.dart';

class PlayerProfileShareService {
  const PlayerProfileShareService._();

  static const watermarkLogoAsset = 'assets/global/Aphidex-icon.png';

  static String fileNameFor(AphidexGame game) =>
      'aphidex_profile_${game == AphidexGame.grounded ? 'grounded' : 'grounded_2'}.png';

  static Future<Uint8List?> capturePanel(GlobalKey boundaryKey) async {
    try {
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) {
        return null;
      }
      var needsPaint = false;
      assert(() {
        needsPaint = boundary.debugNeedsPaint;
        return true;
      }());
      if (needsPaint) {
        return null;
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> sharePng({
    required Uint8List bytes,
    required String fileName,
    required String text,
    Rect? sharePositionOrigin,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
          fileNameOverrides: [fileName],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
