import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../data/enemy_variants.dart';
import '../models/enemy_index_entry.dart';
import 'creature_alias_matcher.dart';

const String scannerGameScopeAll = 'all';
const String scannerGameScopeG1 = 'g1';
const String scannerGameScopeG2 = 'g2';

enum CreatureScannerErrorType {
  invalidImage,
  payloadTooLarge,
  timeout,
  emptyResponse,
  unknown,
}

class CreatureScannerException implements Exception {
  final CreatureScannerErrorType type;
  final String? debugMessage;

  const CreatureScannerException(this.type, {this.debugMessage});
}

class CreatureScannerMatch {
  final String creatureId;
  final String displayName;
  final double confidence;
  final List<String> sourceLabels;
  final List<EnemyIndexEntry> variants;
  final EnemyIndexEntry previewEnemy;

  const CreatureScannerMatch({
    required this.creatureId,
    required this.displayName,
    required this.confidence,
    required this.sourceLabels,
    required this.variants,
    required this.previewEnemy,
  });
}

class CreatureScannerResult {
  final List<CreatureScannerMatch> matches;
  final List<String> rawLabels;
  final List<String> rawWebEntities;
  final bool hasClearMatch;

  const CreatureScannerResult({
    required this.matches,
    required this.rawLabels,
    required this.rawWebEntities,
    required this.hasClearMatch,
  });
}

class CreatureRecognitionPayload {
  final List<String> rawLabels;
  final List<String> rawWebEntities;

  const CreatureRecognitionPayload({
    required this.rawLabels,
    required this.rawWebEntities,
  });
}

abstract class CreatureRecognitionProvider {
  Future<CreatureRecognitionPayload> analyzeImageFile(XFile file);
}

class MlKitRecognitionProvider implements CreatureRecognitionProvider {
  static const Duration _timeout = Duration(seconds: 8);

  @override
  Future<CreatureRecognitionPayload> analyzeImageFile(XFile file) async {
    if (file.path.isEmpty) {
      throw const CreatureScannerException(
        CreatureScannerErrorType.invalidImage,
      );
    }

    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.35),
    );

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final labels = await labeler.processImage(inputImage).timeout(_timeout);
      final rawLabels =
          labels
              .map((label) => label.label.trim())
              .where((label) => label.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      return CreatureRecognitionPayload(
        rawLabels: rawLabels,
        rawWebEntities: const [],
      );
    } on TimeoutException catch (error) {
      throw CreatureScannerException(
        CreatureScannerErrorType.timeout,
        debugMessage: error.message,
      );
    } catch (error) {
      throw CreatureScannerException(
        CreatureScannerErrorType.unknown,
        debugMessage: error.toString(),
      );
    } finally {
      await labeler.close();
    }
  }
}

class CreatureScannerService {
  static const int maxImageBytes = 1500000;
  static const int maxDimension = 1600;
  static const int jpegQuality = 78;

  final CreatureRecognitionProvider provider;
  final CreatureAliasMatcher matcher;
  final List<EnemyIndexEntry> allEnemies;
  final String selectedGameScope;

  const CreatureScannerService({
    required this.provider,
    required this.matcher,
    required this.allEnemies,
    required this.selectedGameScope,
  });

  Future<CreatureScannerResult> scanFile(XFile file) async {
    final compressedFile = await _compressFile(file);
    try {
      final payload = await provider.analyzeImageFile(compressedFile);
      if (payload.rawLabels.isEmpty && payload.rawWebEntities.isEmpty) {
        throw const CreatureScannerException(
          CreatureScannerErrorType.emptyResponse,
        );
      }

      final matchResult = matcher.match(
        rawLabels: payload.rawLabels,
        rawWebEntities: payload.rawWebEntities,
      );
      final resolvedMatches = resolveScannerMatches(
        rawMatches: matchResult.matches,
        allEnemies: allEnemies,
        selectedGameScope: selectedGameScope,
      );

      return CreatureScannerResult(
        matches: resolvedMatches,
        rawLabels: matchResult.rawLabels,
        rawWebEntities: matchResult.rawWebEntities,
        hasClearMatch:
            matcher.isClearSingleMatch(matchResult.matches) &&
            resolvedMatches.length == 1,
      );
    } finally {
      if (compressedFile.path != file.path) {
        unawaited(
          File(
            compressedFile.path,
          ).delete().then((_) => null).catchError((_) => null),
        );
      }
    }
  }

  Future<XFile> _compressFile(XFile file) async {
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

List<CreatureScannerMatch> resolveScannerMatches({
  required List<CreatureAliasMatch> rawMatches,
  required List<EnemyIndexEntry> allEnemies,
  required String selectedGameScope,
}) {
  final grouped = {
    for (final item in groupEnemyIndexEntries(
      allEnemies,
      mergeSharedSpecies: true,
    ))
      item.speciesKey: item,
  };

  final resolved = <CreatureScannerMatch>[];
  for (final match in rawMatches) {
    final entry = grouped[match.creatureId];
    if (entry == null) {
      continue;
    }

    final variants = switch (selectedGameScope) {
      scannerGameScopeG1 =>
        entry.variants.where((enemy) => enemy.game == 'g1').toList(),
      scannerGameScopeG2 =>
        entry.variants.where((enemy) => enemy.game == 'g2').toList(),
      _ => [...entry.variants],
    };

    if (variants.isEmpty) {
      continue;
    }

    final previewEnemy = preferredScannerVariant(
      variants,
      selectedGameScope: selectedGameScope,
      storedPreferredGame: null,
    );
    if (previewEnemy == null) {
      continue;
    }

    resolved.add(
      CreatureScannerMatch(
        creatureId: match.creatureId,
        displayName: previewEnemy.name,
        confidence: match.confidence,
        sourceLabels: match.sourceLabels,
        variants: variants,
        previewEnemy: previewEnemy,
      ),
    );
  }

  return resolved;
}

EnemyIndexEntry? preferredScannerVariant(
  List<EnemyIndexEntry> variants, {
  required String selectedGameScope,
  String? storedPreferredGame,
}) {
  if (variants.isEmpty) {
    return null;
  }

  if (selectedGameScope == scannerGameScopeG1) {
    return variants.where((enemy) => enemy.game == 'g1').firstOrNull ??
        variants.first;
  }
  if (selectedGameScope == scannerGameScopeG2) {
    return variants.where((enemy) => enemy.game == 'g2').firstOrNull ??
        variants.first;
  }

  if (storedPreferredGame != null) {
    final preferred = variants.where(
      (enemy) => enemy.game == storedPreferredGame,
    );
    if (preferred.isNotEmpty) {
      return preferred.first;
    }
  }

  final g2 = variants.where((enemy) => enemy.game == 'g2');
  if (g2.isNotEmpty) {
    return g2.first;
  }
  return variants.first;
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
