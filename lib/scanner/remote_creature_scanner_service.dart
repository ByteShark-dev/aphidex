import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../data/enemy_variants.dart';
import '../data/local_storage.dart';
import '../models/enemy_index_entry.dart';
import 'creature_scanner_service.dart';
import 'scanner_image_compressor.dart';

abstract class RemoteCreatureScannerClient implements CreatureScannerClient {
  Future<RemoteScannerTokenState> loadTokens();
}

class RemoteCreatureScannerService implements RemoteCreatureScannerClient {
  static const Duration _timeout = Duration(seconds: 14);
  static const String _deviceIdKey = 'scanner_remote_device_id';

  final String apiBaseUrl;
  final String clientToken;
  final List<EnemyIndexEntry> allEnemies;
  final String selectedGameScope;
  final String languageCode;
  final http.Client httpClient;
  final ScannerImageCompressor imageCompressor;
  final String? deviceIdOverride;

  RemoteCreatureScannerService({
    required this.apiBaseUrl,
    required this.clientToken,
    required this.allEnemies,
    required this.selectedGameScope,
    required this.languageCode,
    http.Client? httpClient,
    this.imageCompressor = const FlutterScannerImageCompressor(),
    this.deviceIdOverride,
  }) : httpClient = httpClient ?? http.Client();

  @override
  Future<RemoteScannerTokenState> loadTokens() async {
    final deviceId = await _deviceId();
    final response = await _send(
      () => httpClient.get(
        _endpoint('/v1/tokens', {'deviceId': deviceId}),
        headers: _headers(json: false),
      ),
    );

    final body = _decodeJsonObject(response);
    final tokens = body['tokens'];
    if (tokens is! Map) {
      throw const CreatureScannerException(
        CreatureScannerErrorType.unknown,
        debugMessage: 'Missing token payload.',
      );
    }
    return RemoteScannerTokenState.fromJson(tokens.cast<String, dynamic>());
  }

  @override
  Future<CreatureScannerResult> scanFile(XFile file) async {
    final compressedFile = await imageCompressor.compressFile(file);
    try {
      final bytes = await compressedFile.readAsBytes();
      if (bytes.isEmpty) {
        throw const CreatureScannerException(
          CreatureScannerErrorType.invalidImage,
        );
      }

      final allowedCreatures = _allowedCreatures();
      if (allowedCreatures.isEmpty) {
        throw const CreatureScannerException(
          CreatureScannerErrorType.emptyResponse,
        );
      }

      final response = await _send(
        () async => httpClient.post(
          _endpoint('/v1/scan'),
          headers: _headers(),
          body: jsonEncode({
            'deviceId': await _deviceId(),
            'gameScope': selectedGameScope,
            'languageCode': languageCode,
            'imageBase64': base64Encode(bytes),
            'allowedCreatures': allowedCreatures
                .map(remoteScannerAllowedCreaturePayload)
                .toList(growable: false),
          }),
        ),
      );

      final body = _decodeJsonObject(response);
      final tokens = body['tokens'] is Map
          ? RemoteScannerTokenState.fromJson(
              (body['tokens'] as Map).cast<String, dynamic>(),
            )
          : null;
      final remoteCandidates = _remoteCandidates(body['candidates']);
      final matches = resolveRemoteScannerMatches(
        candidates: remoteCandidates,
        allEnemies: allEnemies,
        selectedGameScope: selectedGameScope,
      );
      final multiCreature =
          body['multiCreature'] == true ||
          remoteScannerReasonsSuggestMultiple(remoteCandidates);
      final weak = body['weak'] == true || matches.isEmpty || multiCreature;

      return CreatureScannerResult(
        matches: matches,
        rawLabels: const [],
        rawWebEntities: const [],
        hasClearMatch: isClearRemoteScannerResult(
          matches: matches,
          weak: weak,
          multiCreature: multiCreature,
          selectedGameScope: selectedGameScope,
        ),
        weak: weak,
        multiCreature: multiCreature,
        tokens: tokens,
      );
    } finally {
      deleteTemporaryScannerFile(compressedFile, file);
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    _validateConfiguration();

    late http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException catch (error) {
      throw CreatureScannerException(
        CreatureScannerErrorType.timeout,
        debugMessage: error.message,
      );
    } catch (error) {
      throw CreatureScannerException(
        CreatureScannerErrorType.network,
        debugMessage: error.toString(),
      );
    }

    if (response.statusCode == 402) {
      throw CreatureScannerException(
        CreatureScannerErrorType.outOfTokens,
        debugMessage: _errorMessage(response),
      );
    }
    if (response.statusCode == 429) {
      throw CreatureScannerException(
        CreatureScannerErrorType.dailyLimit,
        debugMessage: _errorMessage(response),
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CreatureScannerException(
        CreatureScannerErrorType.setupRequired,
        debugMessage: _errorMessage(response),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CreatureScannerException(
        CreatureScannerErrorType.network,
        debugMessage: _errorMessage(response),
      );
    }
    return response;
  }

  Uri _endpoint(String path, [Map<String, String>? query]) {
    final base = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'content-type': 'application/json',
      'authorization': 'Bearer ${clientToken.trim()}',
    };
  }

  void _validateConfiguration() {
    if (apiBaseUrl.trim().isEmpty || clientToken.trim().isEmpty) {
      throw const CreatureScannerException(
        CreatureScannerErrorType.setupRequired,
        debugMessage: 'Scanner API URL or client token is missing.',
      );
    }
  }

  Future<String> _deviceId() async {
    if (deviceIdOverride != null && deviceIdOverride!.trim().isNotEmpty) {
      return deviceIdOverride!.trim();
    }

    final stored = LocalStorage.getString(_deviceIdKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final id =
        'aphidex-${DateTime.now().microsecondsSinceEpoch}-${base64UrlEncode(bytes).replaceAll('=', '')}';
    await LocalStorage.setString(_deviceIdKey, id);
    return id;
  }

  List<EnemyIndexEntry> _allowedCreatures() {
    return switch (selectedGameScope) {
      scannerGameScopeG1 =>
        allEnemies.where((enemy) => enemy.game == 'g1').toList(),
      scannerGameScopeG2 =>
        allEnemies.where((enemy) => enemy.game == 'g2').toList(),
      _ => [...allEnemies],
    };
  }

  Map<String, dynamic> _decodeJsonObject(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {
      // Converted below into the scanner exception type used by the UI.
    }
    throw const CreatureScannerException(
      CreatureScannerErrorType.unknown,
      debugMessage: 'Scanner service returned invalid JSON.',
    );
  }

  String? _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          return error['message']?.toString();
        }
      }
    } catch (_) {
      return response.body;
    }
    return response.body;
  }

  List<RemoteScannerCandidate> _remoteCandidates(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final candidates = <RemoteScannerCandidate>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final id = item['id']?.toString().trim() ?? '';
      if (id.isEmpty) {
        continue;
      }
      final confidence = switch (item['confidence']) {
        final num value => value.toDouble().clamp(0, 1).toDouble(),
        _ => 0.0,
      };
      final reason = item['reason']?.toString().trim() ?? '';
      candidates.add(
        RemoteScannerCandidate(id: id, confidence: confidence, reason: reason),
      );
    }
    return candidates;
  }
}

class RemoteScannerCandidate {
  final String id;
  final double confidence;
  final String reason;

  const RemoteScannerCandidate({
    required this.id,
    required this.confidence,
    required this.reason,
  });
}

Map<String, Object> remoteScannerAllowedCreaturePayload(EnemyIndexEntry enemy) {
  return {
    'id': enemy.id,
    'name': enemy.name,
    'game': enemy.game,
    'speciesKey': enemy.speciesKey,
    'visualTags': remoteScannerVisualTags(enemy),
  };
}

List<String> remoteScannerVisualTags(EnemyIndexEntry enemy) {
  final tags = <String>{};
  switch (_baseVisualGroupFor(enemy)) {
    case 'ant':
      tags.addAll(const ['ant', 'walking', 'six legs', 'no wings']);
      break;
    case 'wasp':
      tags.addAll(const ['wasp', 'flying', 'wings', 'yellow black', 'stinger']);
      break;
    case 'bee':
      tags.addAll(const ['bee', 'flying', 'wings', 'fuzzy', 'yellow black']);
      break;
    case 'spider':
      tags.addAll(const ['spider', 'eight legs', 'arachnid']);
      break;
    case 'cockroach':
      tags.addAll(const ['cockroach', 'flat body', 'brown', 'roach']);
      break;
    case 'ladybug':
      tags.addAll(const ['ladybug', 'round shell', 'red shell', 'spots']);
      break;
    case 'mantis':
      tags.addAll(const ['mantis', 'raptorial arms', 'long body']);
      break;
    case 'scorpion':
      tags.addAll(const ['scorpion', 'tail', 'claws']);
      break;
    case 'snail':
      tags.addAll(const ['snail', 'shell', 'slug body']);
      break;
  }

  switch (_specialVariantGroupFor(enemy)) {
    case 'orc':
      tags.addAll(const ['orc', 'controlled', 'glowing', 'infected']);
      break;
    case 'ogrr':
      tags.add('ogrr');
      break;
  }

  return tags.take(10).toList(growable: false);
}

List<CreatureScannerMatch> resolveRemoteScannerMatches({
  required List<RemoteScannerCandidate> candidates,
  required List<EnemyIndexEntry> allEnemies,
  required String selectedGameScope,
}) {
  final byId = {for (final enemy in allEnemies) enemy.id: enemy};
  final grouped = {
    for (final item in groupEnemyIndexEntries(
      allEnemies,
      mergeSharedSpecies: true,
    ))
      item.speciesKey: item.variants,
  };

  final bestByGroup = <String, _ScoredRemoteCandidate>{};
  for (final candidate in candidates) {
    final preview = byId[candidate.id];
    if (preview == null || !_isInScope(preview, selectedGameScope)) {
      continue;
    }

    final variants = (grouped[preview.speciesKey] ?? [preview])
        .where((enemy) => _isInScope(enemy, selectedGameScope))
        .toList(growable: false);
    if (variants.isEmpty) {
      continue;
    }

    final preferred = preferredScannerVariant(
      variants,
      selectedGameScope: selectedGameScope,
    );
    if (preferred == null) {
      continue;
    }

    final scored = _ScoredRemoteCandidate(
      candidate: candidate,
      previewEnemy: preferred,
      variants: variants,
      confidence: _adjustRemoteConfidence(candidate, preview),
    );
    final groupKey = _remoteScannerGroupKey(preview, selectedGameScope);
    final existing = bestByGroup[groupKey];
    if (existing == null ||
        scored.confidence > existing.confidence ||
        (scored.confidence == existing.confidence &&
            scored.candidate.confidence > existing.candidate.confidence)) {
      bestByGroup[groupKey] = scored;
    }
  }

  final matches =
      bestByGroup.values
          .map(
            (scored) => CreatureScannerMatch(
              creatureId: scored.previewEnemy.speciesKey,
              displayName: scored.previewEnemy.name,
              confidence: scored.confidence,
              sourceLabels: scored.candidate.reason.isEmpty
                  ? const []
                  : [scored.candidate.reason],
              variants: scored.variants,
              previewEnemy: scored.previewEnemy,
              isExactIdMatch:
                  scored.variants.length == 1 &&
                  scored.previewEnemy.id == scored.candidate.id,
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => b.confidence.compareTo(a.confidence));

  return _deduplicateRemoteDisplayNames(
    matches,
  ).take(3).toList(growable: false);
}

bool _isInScope(EnemyIndexEntry enemy, String selectedGameScope) {
  return switch (selectedGameScope) {
    scannerGameScopeG1 => enemy.game == 'g1',
    scannerGameScopeG2 => enemy.game == 'g2',
    _ => true,
  };
}

bool isClearRemoteScannerResult({
  required List<CreatureScannerMatch> matches,
  required bool weak,
  required bool multiCreature,
  required String selectedGameScope,
}) {
  if (weak || multiCreature || matches.isEmpty) {
    return false;
  }

  final top = matches.first;
  if (top.confidence < 0.90) {
    return false;
  }

  if (selectedGameScope == scannerGameScopeAll &&
      top.variants.map((enemy) => enemy.game).toSet().length > 1) {
    return false;
  }

  if (matches.length == 1) {
    return true;
  }

  final margin = top.confidence - matches[1].confidence;
  return margin + 0.000001 >= 0.20;
}

bool remoteScannerReasonsSuggestMultiple(
  List<RemoteScannerCandidate> candidates,
) {
  final text = candidates.map((candidate) => candidate.reason).join(' ');
  return _containsAny(_normalizeScannerText(text), const [
    'multiple',
    'more than one',
    'two creatures',
    'several creatures',
    'varias',
    'varios',
    'dos criaturas',
    'mas de una',
    'more than one creature',
  ]);
}

List<CreatureScannerMatch> _deduplicateRemoteDisplayNames(
  List<CreatureScannerMatch> matches,
) {
  final seen = <String>{};
  final deduped = <CreatureScannerMatch>[];
  for (final match in matches) {
    final key = [
      _normalizeScannerText(match.displayName),
      match.creatureId,
      _specialVariantGroupFor(match.previewEnemy),
    ].join(':');
    if (seen.add(key)) {
      deduped.add(match);
    }
  }
  return deduped;
}

String _remoteScannerGroupKey(EnemyIndexEntry enemy, String selectedGameScope) {
  if (selectedGameScope == scannerGameScopeG1 ||
      selectedGameScope == scannerGameScopeG2) {
    return 'id:${enemy.id}';
  }

  final speciesKey = enemy.speciesKey.trim();
  if (speciesKey.isNotEmpty) {
    return 'species:$speciesKey';
  }

  final goldLinkId = enemy.goldLinkId?.trim();
  if (goldLinkId != null && goldLinkId.isNotEmpty) {
    return 'gold:$goldLinkId';
  }

  return 'id:${enemy.id}';
}

double _adjustRemoteConfidence(
  RemoteScannerCandidate candidate,
  EnemyIndexEntry enemy,
) {
  var confidence = candidate.confidence;
  final reason = _normalizeScannerText(candidate.reason);
  final baseGroup = _baseVisualGroupFor(enemy);
  final specialGroup = _specialVariantGroupFor(enemy);

  final wingedEvidence = _containsAny(reason, const [
    'wing',
    'wings',
    'flying',
    'fly',
    'wasp',
    'bee',
    'stinger',
    'yellow black',
    'alas',
    'volando',
    'avispa',
    'abeja',
    'aguijon',
  ]);
  final antEvidence = _containsAny(reason, const [
    'ant',
    'worker ant',
    'soldier ant',
    'walking',
    'six legs',
    'no wings',
    'hormiga',
    'caminando',
    'sin alas',
  ]);

  if (wingedEvidence && baseGroup == 'ant') {
    confidence -= 0.35;
  }
  if (antEvidence && (baseGroup == 'wasp' || baseGroup == 'bee')) {
    confidence -= 0.25;
  }

  final mentionsOgrr = _containsAny(reason, const ['ogrr', 'o g r r']);
  final mentionsOrc = _containsAny(reason, const [
    'orc',
    'o r c',
    'controlled',
    'infected',
    'glowing',
    'controlada',
    'infectada',
    'brillo',
  ]);

  if (mentionsOgrr) {
    confidence += specialGroup == 'ogrr' ? 0.12 : 0;
    if (specialGroup == 'orc') {
      confidence -= 0.25;
    }
  } else if (mentionsOrc) {
    confidence += specialGroup == 'orc' ? 0.08 : 0;
    if (specialGroup == 'ogrr') {
      confidence -= 0.18;
    }
  }

  return confidence.clamp(0, 1).toDouble();
}

String _baseVisualGroupFor(EnemyIndexEntry enemy) {
  final text = _enemyScannerText(enemy);
  if (_containsAny(text, const ['wasp', 'wasp drone', 'avispa'])) {
    return 'wasp';
  }
  if (_containsAny(text, const ['bee', 'abeja'])) {
    return 'bee';
  }
  if (_containsAny(text, const ['spider', 'broodmother', 'arana'])) {
    return 'spider';
  }
  if (_containsAny(text, const ['cockroach', 'roach', 'cucaracha'])) {
    return 'cockroach';
  }
  if (_containsAny(text, const ['ladybug', 'ladybird', 'mariquita'])) {
    return 'ladybug';
  }
  if (_containsAny(text, const ['mantis'])) {
    return 'mantis';
  }
  if (_containsAny(text, const ['scorpion', 'escorpion'])) {
    return 'scorpion';
  }
  if (_containsAny(text, const ['snail', 'caracol'])) {
    return 'snail';
  }
  if (_containsAny(text, const [
    'worker ant',
    'soldier ant',
    'fire ant',
    'red ant',
    'black ant',
    'ant queen',
    'hormiga',
  ])) {
    return 'ant';
  }
  return '';
}

String _specialVariantGroupFor(EnemyIndexEntry enemy) {
  final text = _enemyScannerText(enemy);
  if (_containsAny(text, const ['ogrr', 'o g r r'])) {
    return 'ogrr';
  }
  if (_containsAny(text, const ['orc', 'o r c', 'controlled', 'infected'])) {
    return 'orc';
  }
  return '';
}

String _enemyScannerText(EnemyIndexEntry enemy) {
  return _normalizeScannerText(
    [
      enemy.id,
      enemy.speciesKey,
      enemy.collectionGroup,
      enemy.goldLinkId,
      enemy.name,
    ].whereType<String>().join(' '),
  );
}

String _normalizeScannerText(String text) {
  return text
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll('.', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _containsAny(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) {
      return true;
    }
  }
  return false;
}

class _ScoredRemoteCandidate {
  final RemoteScannerCandidate candidate;
  final EnemyIndexEntry previewEnemy;
  final List<EnemyIndexEntry> variants;
  final double confidence;

  const _ScoredRemoteCandidate({
    required this.candidate,
    required this.previewEnemy,
    required this.variants,
    required this.confidence,
  });
}
