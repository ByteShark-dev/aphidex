import 'dart:convert';
import 'dart:io';

import 'package:aphidex/models/combat_recommendation.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/equipment.dart';
import 'package:aphidex/data/weakpoint_resolver.dart';
import 'package:aphidex/services/damage_calculation_engine.dart';
import 'package:aphidex/services/recommendation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const thresholds = EffectivenessThresholds(
    excellent: 1.5,
    strong: 1.15,
    neutral: .85,
    weak: .5,
  );

  Enemy enemy({String game = 'g2'}) => Enemy.fromJson({
    'id': 'target',
    'speciesKey': 'target',
    'name': {'en': 'Target', 'es': 'Objetivo', 'ru': 'Цель'},
    'game': game,
    'tier': 2,
    'danger': 'medium',
    'isBoss': false,
    'order': 1,
    'defaultGold': false,
    'cardNormal': '',
    'cardGold': '',
    'photo': '',
    'weaknesses': const [],
    'resistances': const [],
    'damageWeaknesses': [
      {'type': 'stabbing', 'bonusPct': 50},
    ],
    'resistancesV2': [
      {'type': 'fresh', 'bonusPct': 25},
    ],
    'weakPoints': [
      {
        'part': 'tail',
        'susceptibleDamage': 'stabbing',
        'susceptibleDamageTypes': ['stabbing'],
        'damageMultiplier': 2,
      },
    ],
  });

  test(
    'compact source has the validated roster and current projectile scope',
    () {
      final source =
          jsonDecode(
                File(
                  'assets/data/g2/combat_recommendations.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final counts = (source['manifest']['counts'] as Map)
          .cast<String, dynamic>();
      expect(counts['weapons'], 58);
      expect(counts['shields'], 9);
      expect(counts['tierUpgradeableWeapons'], 52);
      expect(counts['reachableTiers'], 73);
      expect(counts['enhancementRoutes'], 158);
      expect(counts['projectiles'], 31);
      expect(source['maxEnhancementLevel'], 3);
      expect(source['manifest']['extractorQa'], 'PASS_WITH_SOURCE_WARNINGS');
      final timedAttacks = (source['weapons'] as List)
          .whereType<Map>()
          .expand(
            (weapon) =>
                (weapon['attacks'] as List? ?? const []).whereType<Map>(),
          )
          .where((attack) => (attack['intervalSeconds'] as num?) != null)
          .toList(growable: false);
      expect(timedAttacks, hasLength(108));
      expect(
        timedAttacks.every((attack) => (attack['intervalSeconds'] as num) > 0),
        isTrue,
      );
      final projectileAttacks = (source['projectiles'] as List)
          .whereType<Map>()
          .map((projectile) => projectile['attack'] as Map)
          .toList(growable: false);
      expect(projectileAttacks, hasLength(31));
      expect(
        projectileAttacks.every(
          (attack) =>
              (attack['chargeTime'] as num?) != null &&
              (attack['chargeTime'] as num) > 0,
        ),
        isTrue,
      );
    },
  );

  test('damage calculation applies weaknesses, resistances and hit zones', () {
    final result = const DamageCalculationEngine(thresholds).calculate(
      enemy: enemy(),
      baseDamage: 100,
      physical: 'stabbing',
      element: 'fresh',
      weaponFamily: 'spear',
    );
    expect(result.generalDamage, closeTo(112.5, .001));
    expect(result.bestDamage, closeTo(225, .001));
    expect(result.zones.single.compatible, isTrue);
    expect(result.effectiveness, EffectivenessLevel.neutral);
  });

  test('verified hit intervals produce modifier-aware DPS', () {
    final result = const DamageCalculationEngine(thresholds).calculate(
      enemy: enemy(),
      baseDamage: 100,
      baseDamagePerSecond: 20,
      physical: 'stabbing',
      element: 'fresh',
      weaponFamily: 'spear',
    );
    expect(result.generalDamagePerSecond, closeTo(22.5, .001));
    expect(result.bestDamagePerSecond, closeTo(45, .001));
    expect(result.zones.single.damagePerSecond, closeTo(45, .001));
  });

  test('unknown damage degrades safely without a fabricated score', () {
    final result = const DamageCalculationEngine(
      thresholds,
    ).calculate(enemy: enemy(), baseDamage: null);
    expect(result.generalDamage, isNull);
    expect(result.effectiveness, EffectivenessLevel.unknown);
  });

  test('structured weak point types override legacy any damage labels', () {
    final presentation = const AphidexWeakpointResolver().resolve(
      const WeakPointInfo(
        part: 'tail',
        susceptibleDamage: 'any',
        susceptibleDamageTypes: ['stabbing'],
        weaponFamilies: ['bow', 'spear'],
      ),
    );
    expect(presentation.effectiveDamage, 'stabbing');
    expect(presentation.effectiveDamageTypes, ['stabbing']);
    expect(presentation.weaponFamilies, ['bow', 'spear']);
  });

  test('restricted bow and spear weak points never present as any damage', () {
    final presentation = const AphidexWeakpointResolver().resolve(
      const WeakPointInfo(
        part: 'stinger',
        susceptibleDamage: 'any',
        susceptibleDamageTypes: ['any'],
        weaponFamilies: ['bow', 'spear'],
      ),
    );
    expect(presentation.effectiveDamage, 'stabbing');
    expect(presentation.effectiveDamageTypes, ['stabbing']);
  });

  test(
    'restricted axe sword and dagger weak points retain cutting and slashing',
    () {
      final presentation = const AphidexWeakpointResolver().resolve(
        const WeakPointInfo(
          part: 'legs',
          susceptibleDamage: 'any',
          susceptibleDamageTypes: ['any'],
          weaponFamilies: ['axe', 'sword', 'dagger'],
        ),
      );
      expect(presentation.effectiveDamage, 'chopping and slashing');
      expect(presentation.effectiveDamageTypes.toSet(), {
        'chopping',
        'slashing',
      });
    },
  );

  test('infusion resistance can make a flavour ineffective', () {
    final result = const DamageCalculationEngine(thresholds).calculate(
      enemy: enemy(),
      baseDamage: 100,
      element: 'fresh',
      additionalResistances: const [BonusInfo(type: 'fresh', bonusPct: 100)],
    );
    expect(result.generalDamage, 0);
    expect(result.effectiveness, EffectivenessLevel.ineffective);
  });

  test('recommendations are hidden completely for Grounded 1', () {
    final engine = RecommendationEngine(
      combat: const CombatRecommendationCatalog(
        qaStatus: 'PASS',
        maxEnhancementLevel: 3,
        thresholds: thresholds,
        weapons: [],
        shields: [],
        projectiles: [],
      ),
      equipment: const EquipmentCatalog(items: [], armorSets: []),
    );
    expect(engine.recommend(enemy(game: 'g1')), isEmpty);
  });

  test('off-hand utility never increases offensive damage', () {
    final weapon = EquipmentItem.fromJson({
      'id': 'weapon',
      'domain': 'weapon',
      'name': {'en': 'Weapon', 'es': 'Arma', 'ru': 'Оружие'},
      'tier': 2,
      'icon': '',
      'normalizedType': 'weapon',
      'normalizedSubtype': 'spear',
      'classificationSource': 'test',
      'classificationFallbackUsed': false,
      'acquisition': {'status': 'unresolved_acquisition'},
    });
    final shield = EquipmentItem.fromJson({
      'id': 'shield',
      'domain': 'shield',
      'name': {'en': 'Shield', 'es': 'Escudo', 'ru': 'Щит'},
      'tier': 2,
      'icon': '',
      'normalizedType': 'shield',
      'normalizedSubtype': 'shield',
      'classificationSource': 'test',
      'classificationFallbackUsed': false,
      'acquisition': {'status': 'unresolved_acquisition'},
    });
    const profile = CombatWeaponProfile(
      id: 'weapon',
      tier: 2,
      shieldCompatible: true,
      attacks: [
        CombatAttackProfile(
          base: CombatDamageState(damage: 100, physical: 'stabbing'),
          charged: CombatDamageState(),
          perfect: CombatDamageState(),
        ),
      ],
    );
    final values = RecommendationEngine(
      combat: const CombatRecommendationCatalog(
        qaStatus: 'PASS',
        maxEnhancementLevel: 3,
        thresholds: thresholds,
        weapons: [profile],
        shields: [
          CombatShieldProfile(id: 'shield', tier: 2, blockDamageMultiplier: .2),
        ],
        projectiles: [],
      ),
      equipment: EquipmentCatalog(items: [weapon, shield], armorSets: const []),
    ).recommend(enemy());
    final withShield = values.firstWhere(
      (value) => value.loadout.shield != null,
    );
    final withoutShield = values.firstWhere(
      (value) => value.loadout.shield == null,
    );
    expect(withShield.damage.bestDamage, withoutShield.damage.bestDamage);
    expect(withShield.defensiveUtility, greaterThan(0));
  });

  test('a full melee combo outranks a resisted projectile hit', () {
    EquipmentItem item(String id, String subtype) => EquipmentItem.fromJson({
      'id': id,
      'domain': 'weapon',
      'name': {'en': id, 'es': id, 'ru': id},
      'tier': 2,
      'icon': '',
      'normalizedType': 'weapon',
      'normalizedSubtype': subtype,
      'classificationSource': 'test',
      'classificationFallbackUsed': false,
      'acquisition': {'status': 'unresolved_acquisition'},
    });
    final resistantTarget = Enemy.fromJson({
      'id': 'resistant-target',
      'speciesKey': 'resistant-target',
      'name': {'en': 'Target', 'es': 'Objetivo', 'ru': 'Цель'},
      'game': 'g2',
      'tier': 2,
      'danger': 'medium',
      'isBoss': false,
      'order': 1,
      'defaultGold': false,
      'cardNormal': '',
      'cardGold': '',
      'photo': '',
      'weaknesses': const [],
      'resistances': const [],
      'resistancesV2': [
        {'type': 'stabbing', 'bonusPct': 25},
      ],
    });
    const noDamage = CombatDamageState();
    const strike = CombatAttackProfile(
      base: CombatDamageState(damage: 50, physical: 'slashing'),
      charged: noDamage,
      perfect: noDamage,
    );
    final values = RecommendationEngine(
      combat: const CombatRecommendationCatalog(
        qaStatus: 'PASS',
        maxEnhancementLevel: 3,
        thresholds: thresholds,
        weapons: [
          CombatWeaponProfile(
            id: 'melee',
            tier: 2,
            shieldCompatible: false,
            attacks: [strike, strike, strike],
          ),
          CombatWeaponProfile(
            id: 'bow',
            tier: 2,
            shieldCompatible: false,
            attacks: [
              CombatAttackProfile(
                base: CombatDamageState(damage: 1, physical: 'stabbing'),
                charged: noDamage,
                perfect: noDamage,
              ),
            ],
          ),
        ],
        shields: [],
        projectiles: [
          ProjectileItem(
            id: 'arrow',
            tier: 2,
            family: 'arrow',
            icon: '',
            launcherIds: ['bow'],
            attack: CombatAttackProfile(
              base: CombatDamageState(damage: 140, physical: 'stabbing'),
              charged: noDamage,
              perfect: noDamage,
            ),
          ),
        ],
      ),
      equipment: EquipmentCatalog(
        items: [item('melee', 'sword'), item('bow', 'bow')],
        armorSets: const [],
      ),
    ).recommend(resistantTarget);
    expect(values.first.loadout.weapon.id, 'melee');
    expect(values.first.damage.generalDamage, 150);
  });

  test('known nominal DPS outranks an unmeasured damage total', () {
    EquipmentItem item(String id) => EquipmentItem.fromJson({
      'id': id,
      'domain': 'weapon',
      'name': {'en': id, 'es': id, 'ru': id},
      'tier': 2,
      'icon': '',
      'normalizedType': 'weapon',
      'normalizedSubtype': 'spear',
      'classificationSource': 'test',
      'classificationFallbackUsed': false,
      'acquisition': {'status': 'unresolved_acquisition'},
    });
    const noDamage = CombatDamageState();
    final recommendations = RecommendationEngine(
      combat: CombatRecommendationCatalog(
        qaStatus: 'PASS',
        maxEnhancementLevel: 3,
        thresholds: thresholds,
        weapons: [
          CombatWeaponProfile(
            id: 'unmeasured',
            tier: 2,
            shieldCompatible: false,
            attacks: const [
              CombatAttackProfile(
                base: CombatDamageState(damage: 500, physical: 'stabbing'),
                charged: noDamage,
                perfect: noDamage,
              ),
            ],
          ),
          CombatWeaponProfile(
            id: 'timed',
            tier: 2,
            shieldCompatible: false,
            attacks: const [
              CombatAttackProfile(
                base: CombatDamageState(damage: 100, physical: 'stabbing'),
                charged: noDamage,
                perfect: noDamage,
                intervalSeconds: 1,
              ),
            ],
          ),
        ],
        shields: const [],
        projectiles: const [],
      ),
      equipment: EquipmentCatalog(
        items: [item('unmeasured'), item('timed')],
        armorSets: const [],
      ),
    ).recommend(enemy());
    expect(recommendations.first.loadout.weapon.id, 'timed');
    expect(recommendations.first.damage.generalDamagePerSecond, 150);
  });

  test(
    'projectile charge time supplies nominal DPS without a reload guess',
    () {
      const noDamage = CombatDamageState();
      const chargedProjectile = CombatAttackProfile(
        base: CombatDamageState(damage: 25, physical: 'stabbing'),
        charged: CombatDamageState(damage: 50, physical: 'stabbing'),
        perfect: CombatDamageState(damage: 55, physical: 'stabbing'),
        chargeTime: 1.5,
      );
      final result = RecommendationEngine(
        combat: const CombatRecommendationCatalog(
          qaStatus: 'PASS',
          maxEnhancementLevel: 3,
          thresholds: thresholds,
          weapons: [
            CombatWeaponProfile(
              id: 'bow',
              tier: 2,
              shieldCompatible: false,
              attacks: [
                CombatAttackProfile(
                  base: noDamage,
                  charged: noDamage,
                  perfect: noDamage,
                ),
              ],
            ),
          ],
          shields: [],
          projectiles: [
            ProjectileItem(
              id: 'arrow',
              tier: 2,
              family: 'ammo',
              icon: '',
              launcherIds: ['bow'],
              attack: chargedProjectile,
            ),
          ],
        ),
        equipment: EquipmentCatalog(
          items: [
            EquipmentItem.fromJson({
              'id': 'bow',
              'domain': 'weapon',
              'name': {'en': 'Bow', 'es': 'Arco', 'ru': 'Лук'},
              'tier': 2,
              'icon': '',
              'normalizedType': 'weapon',
              'normalizedSubtype': 'bow',
              'classificationSource': 'test',
              'classificationFallbackUsed': false,
              'acquisition': {'status': 'unresolved_acquisition'},
            }),
          ],
          armorSets: const [],
        ),
      ).recommend(enemy());

      expect(result.single.damage.generalDamage, 82.5);
      expect(result.single.damage.generalDamagePerSecond, closeTo(55, .001));
    },
  );
}
