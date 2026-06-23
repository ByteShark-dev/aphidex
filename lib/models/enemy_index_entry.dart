import 'enemy.dart';

class EnemyIndexEntry {
  final String id;
  final String speciesKey;
  final String? collectionGroup;
  final String name;
  final int? order;
  final String game;
  final String? temperament;
  final int tier;
  final String danger;
  final bool isBoss;
  final List<String> weaknesses;
  final List<String> resistances;
  final bool defaultGold;
  final String? goldLinkId;
  final String cardNormal;
  final String cardGold;
  final HealthInfo? health;

  const EnemyIndexEntry({
    required this.id,
    required this.speciesKey,
    this.collectionGroup,
    required this.name,
    required this.order,
    required this.game,
    this.temperament,
    required this.tier,
    required this.danger,
    required this.isBoss,
    required this.weaknesses,
    required this.resistances,
    required this.defaultGold,
    this.goldLinkId,
    required this.cardNormal,
    required this.cardGold,
    this.health,
  });

  factory EnemyIndexEntry.fromJson(Map<String, dynamic> json) =>
      EnemyIndexEntry(
        id: json['id'] as String,
        speciesKey: (json['speciesKey'] as String?) ?? (json['id'] as String),
        collectionGroup: json['collectionGroup'] as String?,
        name: (json['name'] ?? '').toString(),
        order: json['order'] as int?,
        game: json['game'] as String,
        temperament: json['temperament'] as String?,
        tier: json['tier'] as int,
        danger: json['danger'] as String,
        isBoss: json['isBoss'] as bool? ?? false,
        weaknesses: List<String>.from(json['weaknesses'] ?? const []),
        resistances: List<String>.from(json['resistances'] ?? const []),
        defaultGold: json['defaultGold'] as bool? ?? false,
        goldLinkId: json['goldLinkId'] as String?,
        cardNormal: json['cardNormal'] as String,
        cardGold: json['cardGold'] as String,
        health: (json['health'] is Map)
            ? HealthInfo.fromJson(
                (json['health'] as Map).cast<String, dynamic>(),
              )
            : null,
      );

  factory EnemyIndexEntry.fromEnemy(Enemy enemy, String languageCode) =>
      EnemyIndexEntry(
        id: enemy.id,
        speciesKey: enemy.speciesKey,
        collectionGroup: enemy.collectionGroup,
        name: enemy.name.resolve(languageCode),
        order: enemy.order,
        game: enemy.game,
        temperament: enemy.temperament,
        tier: enemy.tier,
        danger: enemy.danger,
        isBoss: enemy.isBoss,
        weaknesses: enemy.weaknesses,
        resistances: enemy.resistances,
        defaultGold: enemy.defaultGold,
        goldLinkId: enemy.goldLinkId,
        cardNormal: enemy.cardNormal,
        cardGold: enemy.cardGold,
        health: enemy.health,
      );
}
