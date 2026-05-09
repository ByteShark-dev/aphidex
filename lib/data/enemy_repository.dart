import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/enemy.dart';

class EnemyRepository {
  static Future<List<Enemy>>? _g1Future;
  static Future<List<Enemy>>? _g2Future;
  static Future<List<Enemy>>? _allFuture;

  static Future<List<Enemy>> loadAll() async {
    return _allFuture ??= _loadAllInternal();
  }

  static Future<List<Enemy>> loadGame(String game) {
    switch (game) {
      case 'g1':
        return _g1Future ??= _loadFile('assets/data/enemies_g1.json');
      case 'g2':
        return _g2Future ??= _loadFile('assets/data/enemies_g2.json');
      default:
        return loadAll();
    }
  }

  static void warmUpGame(String game) {
    unawaited(loadGame(game));
  }

  static Future<List<Enemy>> _loadAllInternal() async {
    final g1 = await loadGame('g1');
    final g2 = await loadGame('g2');
    return [...g1, ...g2];
  }

  static Future<List<Enemy>> _loadFile(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = await compute(_decodeEnemyJsonMaps, raw);
      return decoded.map(Enemy.fromJson).toList(growable: false);
    } catch (error) {
      throw StateError('Failed to load enemy data from $path: $error');
    }
  }
}

List<Map<String, dynamic>> _decodeEnemyJsonMaps(String raw) {
  final List<dynamic> data = json.decode(raw) as List<dynamic>;
  return data
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
