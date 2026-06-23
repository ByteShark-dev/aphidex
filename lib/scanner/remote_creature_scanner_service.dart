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
                .map(
                  (enemy) => {
                    'id': enemy.id,
                    'name': enemy.name,
                    'game': enemy.game,
                    'speciesKey': enemy.speciesKey,
                  },
                )
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
      final weak = body['weak'] == true || matches.isEmpty;

      return CreatureScannerResult(
        matches: matches,
        rawLabels: const [],
        rawWebEntities: const [],
        hasClearMatch:
            !weak && matches.length == 1 && matches.first.confidence >= 0.75,
        weak: weak,
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

  final matches = <CreatureScannerMatch>[];
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

    matches.add(
      CreatureScannerMatch(
        creatureId: preview.speciesKey,
        displayName: preview.name,
        confidence: candidate.confidence,
        sourceLabels: candidate.reason.isEmpty ? const [] : [candidate.reason],
        variants: variants,
        previewEnemy: preview,
        isExactIdMatch: true,
      ),
    );
  }
  return matches;
}

bool _isInScope(EnemyIndexEntry enemy, String selectedGameScope) {
  return switch (selectedGameScope) {
    scannerGameScopeG1 => enemy.game == 'g1',
    scannerGameScopeG2 => enemy.game == 'g2',
    _ => true,
  };
}
