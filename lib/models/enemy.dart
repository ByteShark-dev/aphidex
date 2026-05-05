import 'dart:convert';

class Enemy {
  final String id;
  final String speciesKey;
  final String? collectionGroup;
  final LocalizedText name;
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
  final String photo;

  final HealthInfo? health;
  final List<BonusInfo> elementalWeaknesses;
  final List<BonusInfo> damageWeaknesses;
  final List<BonusInfo> resistancesV2;
  final WeakPointInfo? weakPoint;
  final List<WeakPointInfo> weakPoints;
  final List<EnemyAttack> attacks;
  final LocalizedText? description;
  final LocalizedText? behavior;
  final LocalizedText? interactionWithPlayer;
  final LocalizedText? interactionWithCreatures;
  final LocalizedText? strategy;
  final List<LocalizedText> environments;
  final LocalizedText? respawnInfo;
  final List<LootEntry> loot;
  final List<AdvancedLootEntry> advancedLootTable;
  final List<RewardUnlockInfo> rewardUnlocks;
  final CombatStats? combatStats;
  final List<String> inflictsEffects;
  final List<LocalizedText> inflicts;
  final List<LocalizedText> specialTraits;
  final List<AbilityInfo> abilities;
  final List<BossPhaseInfo> bossPhases;

  const Enemy({
    required this.order,
    required this.defaultGold,
    this.goldLinkId,
    required this.id,
    required this.speciesKey,
    this.collectionGroup,
    required this.name,
    required this.game,
    required this.tier,
    required this.danger,
    required this.isBoss,
    this.temperament,
    required this.weaknesses,
    required this.resistances,
    required this.cardNormal,
    required this.cardGold,
    required this.photo,
    this.health,
    this.elementalWeaknesses = const [],
    this.damageWeaknesses = const [],
    this.resistancesV2 = const [],
    this.weakPoint,
    this.weakPoints = const [],
    this.attacks = const [],
    this.description,
    this.behavior,
    this.interactionWithPlayer,
    this.interactionWithCreatures,
    this.strategy,
    this.environments = const [],
    this.respawnInfo,
    this.loot = const [],
    this.advancedLootTable = const [],
    this.rewardUnlocks = const [],
    this.combatStats,
    this.inflictsEffects = const [],
    this.inflicts = const [],
    this.specialTraits = const [],
    this.abilities = const [],
    this.bossPhases = const [],
  });

  factory Enemy.fromJson(Map<String, dynamic> json) {
    List<BonusInfo> bonusList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => BonusInfo.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    List<EnemyAttack> attackList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => EnemyAttack.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    List<LocalizedText> localizedTextList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .map((item) => LocalizedText.fromJson(item))
            .where((item) => !item.isEmpty)
            .toList();
      }
      return const [];
    }

    List<LootEntry> lootList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => LootEntry.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    List<AdvancedLootEntry> advancedLootList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map(
              (item) => AdvancedLootEntry.fromJson(item.cast<String, dynamic>()),
            )
            .toList();
      }
      return const [];
    }

    List<RewardUnlockInfo> rewardUnlockList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => RewardUnlockInfo.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    List<AbilityInfo> abilityList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => AbilityInfo.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    List<WeakPointInfo> weakPointList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => WeakPointInfo.fromJson(item.cast<String, dynamic>()))
            .where((item) => item.part.isNotEmpty)
            .toList();
      }
      return const [];
    }

    List<BossPhaseInfo> phaseList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => BossPhaseInfo.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    return Enemy(
      id: json['id'] as String,
      speciesKey: (json['speciesKey'] as String?) ?? (json['id'] as String),
      collectionGroup: json['collectionGroup'] as String?,
      name: LocalizedText.fromJson(json['name'], legacyLanguage: 'en'),
      game: json['game'] as String,
      temperament: json['temperament'] as String?,
      tier: json['tier'] as int,
      danger: json['danger'] as String,
      isBoss: json['isBoss'] as bool? ?? false,
      order: json['order'] as int?,
      defaultGold: json['defaultGold'] as bool? ?? false,
      goldLinkId: json['goldLinkId'] as String?,
      cardNormal: json['cardNormal'] as String,
      cardGold: json['cardGold'] as String,
      photo: json['photo'] as String,
      weaknesses: List<String>.from(json['weaknesses'] ?? const []),
      resistances: List<String>.from(json['resistances'] ?? const []),
      health: (json['health'] is Map)
          ? HealthInfo.fromJson((json['health'] as Map).cast<String, dynamic>())
          : null,
      elementalWeaknesses: bonusList('elementalWeaknesses'),
      damageWeaknesses: bonusList('damageWeaknesses'),
      resistancesV2: bonusList('resistancesV2'),
      weakPoint: (json['weakPoint'] is Map)
          ? WeakPointInfo.fromJson(
              (json['weakPoint'] as Map).cast<String, dynamic>(),
            )
          : null,
      weakPoints: weakPointList('weakPoints'),
      attacks: attackList('attacks'),
      description: LocalizedText.maybeFromJson(json['description']),
      behavior: LocalizedText.maybeFromJson(json['behavior']),
      interactionWithPlayer: LocalizedText.maybeFromJson(
        json['interactionWithPlayer'],
      ),
      interactionWithCreatures: LocalizedText.maybeFromJson(
        json['interactionWithCreatures'],
      ),
      strategy: LocalizedText.maybeFromJson(json['strategy']),
      environments: localizedTextList('environments'),
      respawnInfo: LocalizedText.maybeFromJson(json['respawnInfo']),
      loot: lootList('loot'),
      advancedLootTable: advancedLootList('advancedLootTable'),
      rewardUnlocks: rewardUnlockList('rewardUnlocks'),
      combatStats: (json['combatStats'] is Map)
          ? CombatStats.fromJson(
              (json['combatStats'] as Map).cast<String, dynamic>(),
            )
          : null,
      inflictsEffects: List<String>.from(json['inflictsEffects'] ?? const []),
      inflicts: localizedTextList('inflicts'),
      specialTraits: localizedTextList('specialTraits'),
      abilities: abilityList('abilities'),
      bossPhases: phaseList('bossPhases'),
    );
  }

  List<WeakPointInfo> get resolvedWeakPoints {
    if (weakPoints.isNotEmpty) {
      return weakPoints;
    }
    if (weakPoint != null) {
      return [weakPoint!];
    }
    return const [];
  }
}

class LocalizedText {
  final String? es;
  final String? en;
  final String? ru;

  const LocalizedText({this.es, this.en, this.ru});

  factory LocalizedText.fromJson(dynamic json, {String legacyLanguage = 'es'}) {
    if (json is Map) {
      return LocalizedText(
        es: _normalize(json['es']),
        en: _normalize(json['en']),
        ru: _normalize(json['ru']),
      );
    }

    final legacyValue = _normalize(json);
    if (legacyValue == null) {
      return const LocalizedText();
    }

    switch (legacyLanguage) {
      case 'en':
        return LocalizedText(en: legacyValue);
      case 'ru':
        return LocalizedText(ru: legacyValue);
      default:
        return LocalizedText(es: legacyValue);
    }
  }

  static LocalizedText? maybeFromJson(
    dynamic json, {
    String legacyLanguage = 'es',
  }) {
    final value = LocalizedText.fromJson(json, legacyLanguage: legacyLanguage);
    return value.isEmpty ? null : value;
  }

  bool get isEmpty =>
      (es == null || es!.isEmpty) &&
      (en == null || en!.isEmpty) &&
      (ru == null || ru!.isEmpty);

  String resolve(String languageCode) {
    final resolved = switch (languageCode) {
      'en' => en ?? es ?? ru ?? '',
      'ru' => ru ?? es ?? en ?? '',
      _ => es ?? en ?? ru ?? '',
    };
    return _repairLocalizedText(resolved);
  }

  // ignore: unused_element
  static String _repairMojibake(String value) {
    if (!value.contains(RegExp(r'[ÃÐÑÂ]'))) {
      return value;
    }

    try {
      return utf8.decode(latin1.encode(value), allowMalformed: true);
    } catch (_) {
      return value;
    }
  }

  static String? _normalize(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return _repairLocalizedText(text);
  }

  static String _repairLocalizedText(String value) {
    final mojibakePattern = RegExp(r'[ÃÂÐÑâ€¢œž€™“”\uFFFD]');
    var repaired = value.replaceAll('\u00A0', ' ');

    for (var pass = 0; pass < 3; pass++) {
      if (!mojibakePattern.hasMatch(repaired)) {
        break;
      }

      try {
        final decoded = utf8.decode(
          latin1.encode(repaired),
          allowMalformed: true,
        );
        if (decoded == repaired) {
          break;
        }
        repaired = decoded;
      } catch (_) {
        break;
      }
    }

    return repaired;
  }
}

class HealthInfo {
  final int rating;
  final int? value;

  const HealthInfo({required this.rating, this.value});

  factory HealthInfo.fromJson(Map<String, dynamic> json) => HealthInfo(
    rating: (json['rating'] ?? 1) as int,
    value: json['value'] as int?,
  );
}

class BonusInfo {
  final String type;
  final int bonusPct;

  const BonusInfo({required this.type, required this.bonusPct});

  factory BonusInfo.fromJson(Map<String, dynamic> json) => BonusInfo(
    type: (json['type'] ?? '') as String,
    bonusPct: (json['bonusPct'] ?? 0) as int,
  );
}

class WeakPointInfo {
  final String part;
  final String susceptibleDamage;

  const WeakPointInfo({required this.part, required this.susceptibleDamage});

  factory WeakPointInfo.fromJson(Map<String, dynamic> json) => WeakPointInfo(
    part: (json['part'] ?? '') as String,
    susceptibleDamage: (json['susceptibleDamage'] ?? 'any') as String,
  );
}

class EnemyAttack {
  final LocalizedText name;
  final List<String> tags;
  final LocalizedText? tell;
  final LocalizedText? howToAvoid;
  final LocalizedText? notes;

  const EnemyAttack({
    required this.name,
    this.tags = const [],
    this.tell,
    this.howToAvoid,
    this.notes,
  });

  factory EnemyAttack.fromJson(Map<String, dynamic> json) => EnemyAttack(
    name: LocalizedText.fromJson(json['name']),
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    tell: LocalizedText.maybeFromJson(json['tell']),
    howToAvoid: LocalizedText.maybeFromJson(json['howToAvoid']),
    notes: LocalizedText.maybeFromJson(json['notes']),
  );
}

class LootEntry {
  final String section;
  final LocalizedText item;
  final int minCount;
  final int maxCount;
  final LocalizedText? notes;

  const LootEntry({
    required this.section,
    required this.item,
    required this.minCount,
    required this.maxCount,
    this.notes,
  });

  factory LootEntry.fromJson(Map<String, dynamic> json) => LootEntry(
    section: (json['section'] ?? 'loot') as String,
    item: LocalizedText.fromJson(json['item'], legacyLanguage: 'en'),
    minCount: (json['minCount'] ?? 0) as int,
    maxCount: (json['maxCount'] ?? 0) as int,
    notes: LocalizedText.maybeFromJson(json['notes']),
  );
}

class AdvancedLootEntry {
  final LocalizedText item;
  final String countLabel;
  final int chancePct;
  final LocalizedText? notes;

  const AdvancedLootEntry({
    required this.item,
    required this.countLabel,
    required this.chancePct,
    this.notes,
  });

  factory AdvancedLootEntry.fromJson(Map<String, dynamic> json) =>
      AdvancedLootEntry(
        item: LocalizedText.fromJson(json['item'], legacyLanguage: 'en'),
        countLabel: (json['countLabel'] ?? '1') as String,
        chancePct: (json['chancePct'] ?? 0) as int,
        notes: LocalizedText.maybeFromJson(json['notes']),
      );
}

class RewardUnlockInfo {
  final String id;
  final String category;
  final LocalizedText name;
  final LocalizedText? detail;
  final int? amount;

  const RewardUnlockInfo({
    required this.id,
    required this.category,
    required this.name,
    this.detail,
    this.amount,
  });

  factory RewardUnlockInfo.fromJson(Map<String, dynamic> json) =>
      RewardUnlockInfo(
        id: (json['id'] ?? '') as String,
        category: (json['category'] ?? 'item') as String,
        name: LocalizedText.fromJson(json['name'], legacyLanguage: 'en'),
        detail: LocalizedText.maybeFromJson(json['detail']),
        amount: json['amount'] as int?,
      );
}

class CombatStats {
  final int? health;
  final int? stunThreshold;
  final int? stunCooldownSeconds;
  final LocalizedText? attackDamageSummary;

  const CombatStats({
    this.health,
    this.stunThreshold,
    this.stunCooldownSeconds,
    this.attackDamageSummary,
  });

  factory CombatStats.fromJson(Map<String, dynamic> json) => CombatStats(
    health: json['health'] as int?,
    stunThreshold: json['stunThreshold'] as int?,
    stunCooldownSeconds: json['stunCooldownSeconds'] as int?,
    attackDamageSummary: LocalizedText.maybeFromJson(json['attackDamageSummary']),
  );
}

class AbilityInfo {
  final LocalizedText name;
  final bool? blockable;
  final bool? breaksGuard;
  final bool? staggers;
  final LocalizedText description;

  const AbilityInfo({
    required this.name,
    this.blockable,
    this.breaksGuard,
    this.staggers,
    required this.description,
  });

  factory AbilityInfo.fromJson(Map<String, dynamic> json) => AbilityInfo(
    name: LocalizedText.fromJson(json['name']),
    blockable: json['blockable'] as bool?,
    breaksGuard: json['breaksGuard'] as bool?,
    staggers: json['staggers'] as bool?,
    description: LocalizedText.fromJson(json['description']),
  );
}

class BossPhaseInfo {
  final String id;
  final LocalizedText label;
  final int? startsAtHealthPct;
  final LocalizedText? trigger;
  final LocalizedText? summary;
  final LocalizedText? aggressionChange;
  final List<LocalizedText> newPatterns;
  final List<EnemyAttack> attacks;
  final List<AbilityInfo> abilities;
  final List<BonusInfo> elementalWeaknesses;
  final List<BonusInfo> damageWeaknesses;
  final List<BonusInfo> resistancesV2;
  final List<String> inflictsEffects;
  final List<LocalizedText> specialTraits;

  const BossPhaseInfo({
    required this.id,
    required this.label,
    this.startsAtHealthPct,
    this.trigger,
    this.summary,
    this.aggressionChange,
    this.newPatterns = const [],
    this.attacks = const [],
    this.abilities = const [],
    this.elementalWeaknesses = const [],
    this.damageWeaknesses = const [],
    this.resistancesV2 = const [],
    this.inflictsEffects = const [],
    this.specialTraits = const [],
  });

  factory BossPhaseInfo.fromJson(Map<String, dynamic> json) {
    List<BonusInfo> bonusList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => BonusInfo.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    List<EnemyAttack> attackList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => EnemyAttack.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    List<AbilityInfo> abilityList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => AbilityInfo.fromJson(item.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }

    List<LocalizedText> localizedTextList(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .map((item) => LocalizedText.fromJson(item))
            .where((item) => !item.isEmpty)
            .toList();
      }
      return const [];
    }

    return BossPhaseInfo(
      id: (json['id'] ?? 'phase1') as String,
      label: LocalizedText.fromJson(
        json['label'] ?? {'en': 'Phase 1', 'es': 'Fase 1', 'ru': 'Фаза 1'},
        legacyLanguage: 'en',
      ),
      startsAtHealthPct: json['startsAtHealthPct'] as int?,
      trigger: LocalizedText.maybeFromJson(json['trigger']),
      summary: LocalizedText.maybeFromJson(json['summary']),
      aggressionChange: LocalizedText.maybeFromJson(json['aggressionChange']),
      newPatterns: localizedTextList('newPatterns'),
      attacks: attackList('attacks'),
      abilities: abilityList('abilities'),
      elementalWeaknesses: bonusList('elementalWeaknesses'),
      damageWeaknesses: bonusList('damageWeaknesses'),
      resistancesV2: bonusList('resistancesV2'),
      inflictsEffects: List<String>.from(json['inflictsEffects'] ?? const []),
      specialTraits: localizedTextList('specialTraits'),
    );
  }
}
