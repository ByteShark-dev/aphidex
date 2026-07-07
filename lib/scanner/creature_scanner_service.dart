import 'dart:async';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';

import '../data/enemy_variants.dart';
import '../models/enemy_index_entry.dart';
import 'creature_alias_matcher.dart';
import 'creature_scanner_errors.dart';
import 'scanner_image_compressor.dart';

export 'creature_scanner_errors.dart';

const String scannerGameScopeAll = 'all';
const String scannerGameScopeG1 = 'g1';
const String scannerGameScopeG2 = 'g2';

class CreatureScannerMatch {
  final String creatureId;
  final String displayName;
  final double confidence;
  final List<String> sourceLabels;
  final List<EnemyIndexEntry> variants;
  final EnemyIndexEntry previewEnemy;
  final bool isExactIdMatch;

  const CreatureScannerMatch({
    required this.creatureId,
    required this.displayName,
    required this.confidence,
    required this.sourceLabels,
    required this.variants,
    required this.previewEnemy,
    this.isExactIdMatch = false,
  });
}

class CreatureScannerResult {
  final List<CreatureScannerMatch> matches;
  final List<String> rawLabels;
  final List<String> rawWebEntities;
  final bool hasClearMatch;
  final bool weak;
  final bool multiCreature;
  final RemoteScannerTokenState? tokens;

  const CreatureScannerResult({
    required this.matches,
    required this.rawLabels,
    required this.rawWebEntities,
    required this.hasClearMatch,
    this.weak = false,
    this.multiCreature = false,
    this.tokens,
  });
}

class RemoteScannerTokenState {
  final String plan;
  final int tokens;
  final int maxTokens;
  final int dailyRefill;
  final int dailyLimit;
  final int usedToday;
  final String usageDate;
  final String lastRefillDate;

  const RemoteScannerTokenState({
    required this.plan,
    required this.tokens,
    required this.maxTokens,
    required this.dailyRefill,
    required this.dailyLimit,
    required this.usedToday,
    required this.usageDate,
    required this.lastRefillDate,
  });

  factory RemoteScannerTokenState.fromJson(Map<String, dynamic> json) {
    return RemoteScannerTokenState(
      plan: (json['plan'] ?? 'free').toString(),
      tokens: _intFromJson(json['tokens']),
      maxTokens: _intFromJson(json['maxTokens']),
      dailyRefill: _intFromJson(json['dailyRefill']),
      dailyLimit: _intFromJson(json['dailyLimit']),
      usedToday: _intFromJson(json['usedToday']),
      usageDate: (json['usageDate'] ?? '').toString(),
      lastRefillDate: (json['lastRefillDate'] ?? '').toString(),
    );
  }

  static int _intFromJson(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
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

abstract class CreatureScannerClient {
  Future<CreatureScannerResult> scanFile(XFile file);
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

class CreatureScannerService implements CreatureScannerClient {
  final CreatureRecognitionProvider provider;
  final CreatureAliasMatcher matcher;
  final List<EnemyIndexEntry> allEnemies;
  final String selectedGameScope;
  final ScannerImageCompressor imageCompressor;

  const CreatureScannerService({
    required this.provider,
    required this.matcher,
    required this.allEnemies,
    required this.selectedGameScope,
    this.imageCompressor = const FlutterScannerImageCompressor(),
  });

  @override
  Future<CreatureScannerResult> scanFile(XFile file) async {
    final compressedFile = await imageCompressor.compressFile(file);
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
      deleteTemporaryScannerFile(compressedFile, file);
    }
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
