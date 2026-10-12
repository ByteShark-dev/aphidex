import 'package:aphidex/data/content_repositories.dart';
import 'package:aphidex/data/effect_catalog.dart';
import 'package:aphidex/data/equipment_effect_index.dart';
import 'package:aphidex/models/equipment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(EquipmentRepository.clearCache);

  test(
    'current extractor weapon roster and Paint Gun are materialized',
    () async {
      final catalog = await EquipmentRepository.load();
      final weapons = catalog.items
          .where((item) => item.domain == EquipmentDomain.weapon)
          .toList();
      final shields = catalog.items
          .where((item) => item.domain == EquipmentDomain.shield)
          .toList();
      final paintGun = weapons.singleWhere((item) => item.id == 'PaintGun');

      expect(weapons, hasLength(58));
      expect(shields, hasLength(9));
      expect(paintGun.name.en, 'Paint Gun');
      expect(paintGun.normalizedSubtype, 'paint_launcher');
      expect(paintGun.combat.ammoAttackSlots, 7);
      expect(paintGun.icon, 'assets/g2/equipment/icons/ICO_PaintGun.png');
    },
  );

  test(
    'weapon type, combo statistics and upgrade effects remain source-backed',
    () async {
      final catalog = await EquipmentRepository.load();
      final staff = catalog.items.singleWhere(
        (item) => item.id == 'StaffCentipede',
      );
      final antClub = catalog.items.singleWhere((item) => item.id == 'AntClub');

      expect(staff.normalizedSubtype, 'staff');
      expect(staff.combat.critChance, .02);
      expect(staff.attacks, isNotEmpty);
      expect(
        staff.effectRelations.map((relation) => relation.effectId),
        containsAll(<String>['venom', 'apply_attack_effect']),
      );
      expect(
        antClub.effectRelations
            .where((relation) => relation.effectId == 'fresh')
            .first
            .origin,
        'upgrade',
      );
      expect(
        antClub.effectRelations
            .where((relation) => relation.effectId == 'general')
            .first
            .origin,
        'attack',
      );
    },
  );

  test('the effect catalog preserves 72 extractor types and all locales', () {
    expect(extractorTechnicalEffectIdAliases, hasLength(72));
    expect(effectCatalogEntryById('AttackDamage')?.id, 'attack_damage');
    expect(effectCatalogEntryById('Venom')?.id, 'venom');
    final attackDamage = effectCatalogEntryById('attack_damage')!;
    expect(attackDamage.category, EffectCategory.damage);
    expect(attackDamage.name.en, isNotEmpty);
    expect(attackDamage.name.es, isNotEmpty);
    expect(attackDamage.name.ru, isNotEmpty);
    expect(
      effectCatalogEntries.where(
        (entry) => entry.category == EffectCategory.trigger,
      ),
      isNotEmpty,
    );
  });

  test(
    'the codex index deduplicates weapons and excludes armor and trinkets',
    () async {
      final catalog = await EquipmentRepository.load();
      final index = EquipmentEffectIndex.fromCatalog(catalog);
      final venom = index.forEffect('venom');
      final staff = venom.singleWhere(
        (match) => match.item.id == 'StaffCentipede',
      );

      expect(staff.origins, containsAll(<String>['equipped', 'attack']));
      expect(
        venom.map((match) => match.item.domain),
        everyElement(anyOf(EquipmentDomain.weapon, EquipmentDomain.shield)),
      );
      expect(
        index
            .forEffect('fresh')
            .singleWhere((match) => match.item.id == 'AntClub')
            .origins,
        contains('upgrade'),
      );
      expect(
        index.forEffect('generic').map((match) => match.item.id),
        contains('AntClub'),
      );
    },
  );
}
