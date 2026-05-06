import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/enemy.dart';

class EnemyRepository {
  static Future<List<Enemy>> loadAll() async {
    final g1 = await _loadFile('assets/data/enemies_g1.json');
    final g2 = await _loadFile('assets/data/enemies_g2.json');
    return [...g1, ...g2];
  }

  static Future<List<Enemy>> _loadFile(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final List data = json.decode(raw);
      return data.map((e) => Enemy.fromJson(e)).toList();
    } catch (error) {
      throw StateError('Failed to load enemy data from $path: $error');
    }
  }
}
