import 'location.dart';

class EquipmentLabel {
  final String en;
  final String es;
  final String ru;

  const EquipmentLabel({required this.en, required this.es, required this.ru});

  factory EquipmentLabel.fromJson(Object? raw) {
    final json = raw is Map
        ? raw.cast<String, dynamic>()
        : const <String, dynamic>{};
    return EquipmentLabel(
      en: json['en']?.toString() ?? '',
      es: json['es']?.toString() ?? json['en']?.toString() ?? '',
      ru: json['ru']?.toString() ?? json['en']?.toString() ?? '',
    );
  }

  String resolve(String languageCode) => switch (languageCode) {
    'es' => es.isNotEmpty ? es : en,
    'ru' => ru.isNotEmpty ? ru : en,
    _ => en,
  };
}

enum EquipmentDomain { weapon, shield, armor, trinket }

class EquipmentAttack {
  final String? sourceRow;
  final String? sourceTable;
  final double? damage;
  final double? chargedDamage;
  final double? perfectChargedDamage;
  final double? stun;
  final double? poiseDamage;
  final double? pushback;
  final double? stamina;
  final double? chargedStamina;
  final double? range;
  final double? chargedRange;
  final double? chargeTime;
  final double? perfectChargedWindow;
  final String? physical;
  final String? element;
  final List<EquipmentStatusEffect> statusEffects;

  const EquipmentAttack({
    this.sourceRow,
    this.sourceTable,
    this.damage,
    this.chargedDamage,
    this.perfectChargedDamage,
    this.stun,
    this.poiseDamage,
    this.pushback,
    this.stamina,
    this.chargedStamina,
    this.range,
    this.chargedRange,
    this.chargeTime,
    this.perfectChargedWindow,
    this.physical,
    this.element,
    this.statusEffects = const [],
  });

  factory EquipmentAttack.fromJson(
    Map<String, dynamic> json,
  ) => EquipmentAttack(
    sourceRow: json['sourceRow']?.toString(),
    sourceTable: json['sourceTable']?.toString(),
    damage: (json['damage'] as num?)?.toDouble(),
    chargedDamage: (json['chargedDamage'] as num?)?.toDouble(),
    perfectChargedDamage: (json['perfectChargedDamage'] as num?)?.toDouble(),
    stun: (json['stun'] as num?)?.toDouble(),
    poiseDamage: (json['poiseDamage'] as num?)?.toDouble(),
    pushback: (json['pushback'] as num?)?.toDouble(),
    stamina: (json['stamina'] as num?)?.toDouble(),
    chargedStamina: (json['chargedStamina'] as num?)?.toDouble(),
    range: (json['range'] as num?)?.toDouble(),
    chargedRange: (json['chargedRange'] as num?)?.toDouble(),
    chargeTime: (json['chargeTime'] as num?)?.toDouble(),
    perfectChargedWindow: (json['perfectChargedWindow'] as num?)?.toDouble(),
    physical: json['physical']?.toString(),
    element: json['element']?.toString(),
    statusEffects: (json['statusEffects'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              EquipmentStatusEffect.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false),
  );
}

/// A source-backed effect relationship for an equipment item.
///
/// The [origin] is deliberately stored as data rather than inferred by the
/// UI: a weapon can expose the same effect naturally, through an attack and
/// through an optional elemental upgrade.
class EquipmentEffectRelation {
  final String effectId;
  final String origin;
  final String? sourceRow;
  final String? activation;
  final double? value;
  final double? duration;

  const EquipmentEffectRelation({
    required this.effectId,
    required this.origin,
    this.sourceRow,
    this.activation,
    this.value,
    this.duration,
  });

  factory EquipmentEffectRelation.fromJson(Map<String, dynamic> json) =>
      EquipmentEffectRelation(
        effectId: json['effectId']?.toString() ?? '',
        origin: json['origin']?.toString() ?? 'equipped',
        sourceRow: json['sourceRow']?.toString(),
        activation: json['activation']?.toString(),
        value: (json['value'] as num?)?.toDouble(),
        duration: (json['duration'] as num?)?.toDouble(),
      );
}

/// Combat properties that belong to the equipment itself instead of to a
/// single attack in a combo.
class EquipmentCombatStats {
  final double? critChance;
  final double? blockDamageMultiplier;
  final double? blockStaminaCost;
  final double? blockStaminaRegenMultiplier;
  final int? ammoAttackSlots;

  const EquipmentCombatStats({
    this.critChance,
    this.blockDamageMultiplier,
    this.blockStaminaCost,
    this.blockStaminaRegenMultiplier,
    this.ammoAttackSlots,
  });

  factory EquipmentCombatStats.fromJson(Map<String, dynamic> json) =>
      EquipmentCombatStats(
        critChance: (json['critChance'] as num?)?.toDouble(),
        blockDamageMultiplier: (json['blockDamageMultiplier'] as num?)
            ?.toDouble(),
        blockStaminaCost: (json['blockStaminaCost'] as num?)?.toDouble(),
        blockStaminaRegenMultiplier:
            (json['blockStaminaRegenMultiplier'] as num?)?.toDouble(),
        ammoAttackSlots: (json['ammoAttackSlots'] as num?)?.round(),
      );
}

class EquipmentStatusEffect {
  final String id;
  final String? row;
  final Map<String, dynamic> source;

  const EquipmentStatusEffect({
    required this.id,
    this.row,
    this.source = const {},
  });

  factory EquipmentStatusEffect.fromJson(Map<String, dynamic> json) =>
      EquipmentStatusEffect(
        id: json['id']?.toString() ?? '',
        row: json['row']?.toString(),
        source: (json['source'] as Map? ?? const {}).cast<String, dynamic>(),
      );
}

class EquipmentIngredient {
  final String itemId;
  final int count;

  const EquipmentIngredient({required this.itemId, required this.count});

  factory EquipmentIngredient.fromJson(Map<String, dynamic> json) =>
      EquipmentIngredient(
        itemId: json['itemId']?.toString() ?? '',
        count: (json['count'] as num?)?.round() ?? 0,
      );
}

class EquipmentRecipe {
  final String id;
  final String? station;
  final List<EquipmentIngredient> requirements;
  final List<Object?> unlockSources;

  const EquipmentRecipe({
    required this.id,
    this.station,
    this.requirements = const [],
    this.unlockSources = const [],
  });

  factory EquipmentRecipe.fromJson(Map<String, dynamic> json) =>
      EquipmentRecipe(
        id: json['id']?.toString() ?? '',
        station: json['station']?.toString(),
        requirements: (json['requirements'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  EquipmentIngredient.fromJson(item.cast<String, dynamic>()),
            )
            .toList(growable: false),
        unlockSources: List<Object?>.from(
          json['unlockSources'] as List? ?? const [],
        ),
      );
}

class EquipmentAcquisition {
  final String status;
  final List<String> methods;
  final List<EquipmentRecipe> recipes;
  final List<EquipmentLootSource> lootSourceReferences;

  const EquipmentAcquisition({
    required this.status,
    this.methods = const [],
    this.recipes = const [],
    this.lootSourceReferences = const [],
  });

  bool get unresolved => status == 'unresolved_acquisition';

  factory EquipmentAcquisition.fromJson(
    Map<String, dynamic> json,
  ) => EquipmentAcquisition(
    status: json['status']?.toString() ?? 'unresolved_acquisition',
    methods: List<String>.from(json['methods'] ?? const []),
    recipes: (json['recipes'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => EquipmentRecipe.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
    lootSourceReferences: (json['lootSourceReferences'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => EquipmentLootSource.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false),
  );
}

/// A confirmed creature whose loot table references this equipment item.
/// The public id is used deliberately so navigation survives technical-id drift.
class EquipmentLootSource {
  final String creatureId;
  final String game;

  /// Card artwork is stored with the source reference so the equipment
  /// library can show the actual creature rather than a generic footprint.
  final String cardAsset;

  const EquipmentLootSource({
    required this.creatureId,
    this.game = 'g2',
    this.cardAsset = '',
  });

  factory EquipmentLootSource.fromJson(Map<String, dynamic> json) =>
      EquipmentLootSource(
        creatureId: json['creatureId']?.toString() ?? '',
        game: json['game']?.toString() ?? 'g2',
        cardAsset: json['cardAsset']?.toString() ?? '',
      );
}

class EquipmentItem {
  final String id;
  final EquipmentDomain domain;
  final EquipmentLabel name;
  final int? tier;
  final String? slot;
  final bool? twoHanded;
  final bool? canBlock;
  final double? durability;
  final String icon;
  final String normalizedType;
  final String normalizedSubtype;
  final String classificationSource;
  final bool classificationFallbackUsed;
  final List<String> effects;
  final List<EquipmentEffectRelation> effectRelations;
  final EquipmentCombatStats combat;
  final List<EquipmentAttack> attacks;
  final List<String> upgradeRoutes;
  final List<EquipmentIngredient> repair;
  final EquipmentAcquisition acquisition;
  final List<LocationRecord> locations;
  final Map<String, dynamic> raw;

  const EquipmentItem({
    required this.id,
    required this.domain,
    required this.name,
    this.tier,
    this.slot,
    this.twoHanded,
    this.canBlock,
    this.durability,
    required this.icon,
    required this.normalizedType,
    required this.normalizedSubtype,
    required this.classificationSource,
    required this.classificationFallbackUsed,
    this.effects = const [],
    this.effectRelations = const [],
    this.combat = const EquipmentCombatStats(),
    this.attacks = const [],
    this.upgradeRoutes = const [],
    this.repair = const [],
    required this.acquisition,
    this.locations = const [],
    required this.raw,
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> json) => EquipmentItem(
    id: json['id']?.toString() ?? '',
    domain: switch (json['domain']) {
      'shield' => EquipmentDomain.shield,
      'armor' => EquipmentDomain.armor,
      'trinket' => EquipmentDomain.trinket,
      _ => EquipmentDomain.weapon,
    },
    name: EquipmentLabel.fromJson(json['name']),
    tier: json['tier'] as int?,
    slot: json['slot']?.toString(),
    twoHanded: json['twoHanded'] as bool?,
    canBlock: json['canBlock'] as bool?,
    durability: (json['durability'] as num?)?.toDouble(),
    icon: json['icon']?.toString() ?? '',
    normalizedType:
        json['normalizedType']?.toString() ??
        json['domain']?.toString() ??
        'special',
    normalizedSubtype: json['normalizedSubtype']?.toString() ?? 'special',
    classificationSource:
        json['classificationSource']?.toString() ?? 'legacy_fallback',
    classificationFallbackUsed:
        json['classificationFallbackUsed'] as bool? ?? true,
    effects: List<String>.from(json['effects'] ?? const []),
    effectRelations: (json['effectRelations'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              EquipmentEffectRelation.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false),
    combat: EquipmentCombatStats.fromJson(
      (json['combat'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    attacks: (json['attacks'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => EquipmentAttack.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
    upgradeRoutes: List<String>.from(json['upgradeRoutes'] ?? const []),
    repair: (json['repair'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => EquipmentIngredient.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false),
    acquisition: EquipmentAcquisition.fromJson(
      (json['acquisition'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    locations: (json['locations'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => LocationRecord.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
    raw: json,
  );
}

class ArmorSet {
  final String id;
  final EquipmentLabel name;
  final List<String> pieces;
  final List<int> tiers;
  final String icon;
  final String iconStrategy;
  final List<String> effects;
  final Map<String, dynamic> protection;

  const ArmorSet({
    required this.id,
    required this.name,
    required this.pieces,
    required this.tiers,
    required this.icon,
    required this.iconStrategy,
    required this.effects,
    required this.protection,
  });

  factory ArmorSet.fromJson(Map<String, dynamic> json) => ArmorSet(
    id: json['id']?.toString() ?? '',
    name: EquipmentLabel.fromJson(json['name']),
    pieces: List<String>.from(json['pieces'] ?? const []),
    tiers: List<int>.from(json['tiers'] ?? const []),
    icon: json['icon']?.toString() ?? '',
    iconStrategy: json['iconStrategy']?.toString() ?? 'primary_piece_fallback',
    effects: List<String>.from(json['effects'] ?? const []),
    protection: (json['protection'] as Map? ?? const {})
        .cast<String, dynamic>(),
  );
}

class EquipmentCatalog {
  final List<EquipmentItem> items;
  final List<ArmorSet> armorSets;

  const EquipmentCatalog({required this.items, required this.armorSets});
}
