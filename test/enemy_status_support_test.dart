import 'dart:io';

import 'package:aphidex/data/effect_catalog.dart';
import 'package:aphidex/data/ui_mapper.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLocalizations immuneLabel', () {
    test('resolves immune label for supported locales', () {
      expect(AppLocalizations(const Locale('es')).immuneLabel, 'Inmune');
      expect(AppLocalizations(const Locale('en')).immuneLabel, 'Immune');
      expect(
        AppLocalizations(const Locale('ru')).immuneLabel,
        '\u0418\u043c\u043c\u0443\u043d\u0438\u0442\u0435\u0442',
      );
    });
  });

  group('UiMapper effectIcon', () {
    test('keeps venom and poison as different assets', () {
      expect(
        UiMapper.effectIcon('venom'),
        isNot(UiMapper.effectIcon('poison')),
      );
      expect(
        UiMapper.effectIcon('venom'),
        'assets/global/effects_damage/Venom.webp',
      );
      expect(
        UiMapper.effectIcon('poison'),
        'assets/global/effects_damage/Poison.webp',
      );
    });

    test('maps gas and gas_hazard to the same asset', () {
      expect(
        UiMapper.effectIcon('gas'),
        'assets/global/effects_damage/Gas_Hazard.webp',
      );
      expect(UiMapper.effectIcon('gas_hazard'), UiMapper.effectIcon('gas'));
    });

    test('maps bleed to its dedicated asset', () {
      expect(
        UiMapper.effectIcon('bleed'),
        'assets/global/effects_damage/Bleed.webp',
      );
    });

    test('maps dust to its dedicated asset', () {
      expect(
        UiMapper.effectIcon('dust'),
        'assets/global/effects_damage/Dust.webp',
      );
    });

    test('maps shock and electricity aliases to the same asset', () {
      expect(
        UiMapper.effectIcon('shock'),
        'assets/global/effects_damage/Tooltype_Shock.webp',
      );
      expect(UiMapper.effectIcon('electricity'), UiMapper.effectIcon('shock'));
    });

    test('maps burning and burn aliases to the same asset', () {
      expect(
        UiMapper.effectIcon('burning'),
        'assets/global/effects_damage/Tooltype_Burning.webp',
      );
      expect(UiMapper.effectIcon('burn'), UiMapper.effectIcon('burning'));
    });

    test('maps water and tang buildup to their dedicated assets', () {
      expect(
        UiMapper.effectIcon('water'),
        'assets/global/effects_damage/Tooltype_Water.png',
      );
      expect(
        UiMapper.effectIcon('tang_buildup'),
        'assets/global/effects_damage/TangBuildUp.webp',
      );
      expect(UiMapper.effectIcon('tang'), UiMapper.effectIcon('tang_buildup'));
    });

    test('maps chill and sizzle to their dedicated assets', () {
      expect(
        UiMapper.effectIcon('chill'),
        'assets/global/effects_damage/Chilling_Attack.png',
      );
      expect(UiMapper.effectIcon('chilling'), UiMapper.effectIcon('chill'));
      expect(
        UiMapper.effectIcon('sizzle'),
        'assets/global/effects_damage/Sizzling_Attack.png',
      );
      expect(UiMapper.effectIcon('heat'), UiMapper.effectIcon('sizzle'));
    });
  });

  group('UiMapper dangerIcon', () {
    test('keeps legacy superior-danger keys readable', () {
      final legacyAlt = EnemyIndexEntry.fromJson({
        'id': 'legacy_alt',
        'name': 'Legacy alt',
        'game': 'g2',
        'tier': 1,
        'danger': 'imposible_alt',
      });
      final legacyAlta = EnemyIndexEntry.fromJson({
        'id': 'legacy_alta',
        'name': 'Legacy alta',
        'game': 'g2',
        'tier': 1,
        'danger': 'imposible_alta',
      });

      expect(legacyAlt.danger, 'imposible_alt');
      expect(legacyAlta.danger, 'imposible_alta');
      expect(
        UiMapper.canonicalDangerLevel(legacyAlt.danger),
        'imposible_superior',
      );
      expect(
        UiMapper.canonicalDangerLevel(legacyAlta.danger),
        'imposible_superior',
      );
      expect(UiMapper.canonicalDangerLevel('media'), 'intermedia');
    });

    test('maps every score band to the formal danger scale', () {
      expect(UiMapper.dangerLevelForScore(0), 'baja');
      expect(UiMapper.dangerLevelForScore(19), 'baja');
      expect(UiMapper.dangerLevelForScore(20), 'intermedia');
      expect(UiMapper.dangerLevelForScore(39), 'intermedia');
      expect(UiMapper.dangerLevelForScore(40), 'alta');
      expect(UiMapper.dangerLevelForScore(59), 'alta');
      expect(UiMapper.dangerLevelForScore(60), 'muy_alta');
      expect(UiMapper.dangerLevelForScore(74), 'muy_alta');
      expect(UiMapper.dangerLevelForScore(75), 'imposible');
      expect(UiMapper.dangerLevelForScore(84), 'imposible');
      expect(UiMapper.dangerLevelForScore(85), 'imposible_superior');
      expect(UiMapper.dangerLevelForScore(89), 'imposible_superior');
      expect(UiMapper.dangerLevelForScore(90), 'extrema');
      expect(UiMapper.dangerLevelForScore(100), 'extrema');
    });

    test('maps hard-to-see dangers to existing assets', () {
      expect(UiMapper.dangerIcon('muy_alta'), 'assets/global/Muy_alta.png');
      expect(UiMapper.dangerIcon('imposible'), 'assets/global/Imposible.png');
      expect(
        UiMapper.dangerIcon('imposible_alt'),
        'assets/global/Imposible_alt.png',
      );
      expect(
        UiMapper.dangerIcon('imposible_superior'),
        'assets/global/Imposible_alt.png',
      );
    });

    test('every supported danger level resolves to a real icon asset', () {
      const validDangers = [
        'baja',
        'media',
        'intermedia',
        'alta',
        'muy_alta',
        'imposible',
        'imposible_alt',
        'imposible_alta',
        'imposible_superior',
        'extrema',
      ];

      for (final danger in validDangers) {
        final asset = UiMapper.dangerIcon(danger);
        expect(asset, isNot('assets/global/Proximamente.png'), reason: danger);
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    });

    test('ogrr superior danger uses the same mapper as normal creatures', () {
      expect(
        UiMapper.canonicalDangerLevel('imposible_superior'),
        UiMapper.canonicalDangerLevel('imposible_alt'),
      );
      expect(
        UiMapper.dangerIcon('imposible_superior'),
        UiMapper.dangerIcon('imposible_alt'),
      );
    });

    test('filter normalization and icon normalization stay aligned', () {
      for (final raw in [
        'imposible_alt',
        'imposible_alta',
        'imposible_superior',
      ]) {
        expect(UiMapper.canonicalDangerLevel(raw), 'imposible_superior');
        expect(
          UiMapper.dangerIcon(raw),
          'assets/global/Imposible_alt.png',
          reason: raw,
        );
      }

      expect(UiMapper.canonicalDangerLevel('alta'), 'alta');
      expect(UiMapper.dangerIcon('alta'), 'assets/global/Alta.png');
    });
  });

  group('AppLocalizations dangerLevelLabel', () {
    test('labels the superior danger consistently', () {
      expect(
        AppLocalizations(const Locale('es')).dangerLevelLabel('imposible_alt'),
        'Imposible Superior',
      );
      expect(
        AppLocalizations(const Locale('en')).dangerLevelLabel('imposible_alta'),
        'Impossible Superior',
      );
      expect(
        AppLocalizations(
          const Locale('es'),
        ).dangerLevelLabel('imposible_superior'),
        'Imposible Superior',
      );
    });

    test('labels the under-construction status in every supported locale', () {
      expect(
        AppLocalizations(const Locale('es')).underConstructionLabel,
        'En construcción',
      );
      expect(
        AppLocalizations(const Locale('en')).underConstructionLabel,
        'Under construction',
      );
      expect(
        AppLocalizations(const Locale('ru')).underConstructionLabel,
        'В разработке',
      );
    });
  });

  group('AppLocalizations susceptibleDamageLabel', () {
    test('labels the mantis nymph eye rule', () {
      expect(
        AppLocalizations(
          const Locale('es'),
        ).susceptibleDamageLabel('stabbing_bows_and_spears'),
        'Perforación (arcos / ballestas / lanzas)',
      );
      expect(
        AppLocalizations(
          const Locale('en'),
        ).susceptibleDamageLabel('stabbing_bows_and_spears'),
        'Stabbing (bows / crossbows / spears)',
      );
    });
  });

  group('AppLocalizations text normalization', () {
    test('exposes clean common spanish labels', () {
      final l10n = AppLocalizations(const Locale('es'));

      expect(l10n.settingsTitle, 'Configuración');
      expect(l10n.automaticLanguage, 'Automático');
      expect(
        l10n.autoLanguageDescription('Español'),
        'Detectado automáticamente: Español',
      );
      expect(l10n.dangerLevelLabel('proximamente'), 'Próximamente');
    });

    test('exposes clean common russian labels', () {
      final l10n = AppLocalizations(const Locale('ru'));

      expect(l10n.groupAngry, 'Агрессивные');
      expect(l10n.groupHarmless, 'Безобидные');
      expect(l10n.bossPhasesTitle, 'Фазы босса');
      expect(l10n.dangerLevelLabel('media'), 'Средняя');
    });
  });

  group('Effect catalog localization', () {
    test('exposes clean codex strings for spanish and russian', () {
      final slashing = effectCatalogEntryById('slashing');
      final sour = effectCatalogEntryById('sour');
      final infection = effectCatalogEntryById('infection');

      expect(slashing, isNotNull);
      expect(slashing!.name.es, 'Tajo');
      expect(
        slashing.description.ru,
        'Урон от лезвий или кромок, которые режут цель сбоку.',
      );

      expect(sour, isNotNull);
      expect(sour!.name.es, 'Ácido');
      expect(
        sour.description.es,
        'Elemento ácido o eléctrico que descarga energía inestable.',
      );

      expect(infection, isNotNull);
      expect(infection!.name.ru, 'Инфекция');
      expect(
        infection.description.es,
        'Estado infeccioso ligado a esporas, hongos o corrupción.',
      );
    });
  });

  group('UiMapper weakPointIcon', () {
    test('maps stinger to its dedicated weak point asset', () {
      expect(
        UiMapper.weakPointIcon('stinger'),
        'assets/global/weak_points/T_UI_Weakspot_Stinger.webp',
      );
    });
  });

  group('formatBonusLabel', () {
    test('shows localized immunity for 100 percent resistances', () {
      const bonus = BonusInfo(type: 'gas', bonusPct: 100);

      expect(
        formatBonusLabel(
          AppLocalizations(const Locale('es')),
          bonus,
          dim: true,
        ),
        'Inmune',
      );
      expect(
        formatBonusLabel(
          AppLocalizations(const Locale('en')),
          bonus,
          dim: true,
        ),
        'Immune',
      );
      expect(
        formatBonusLabel(
          AppLocalizations(const Locale('ru')),
          bonus,
          dim: true,
        ),
        '\u0418\u043c\u043c\u0443\u043d\u0438\u0442\u0435\u0442',
      );
    });

    test('keeps numeric labels for weaknesses and partial resistances', () {
      expect(
        formatBonusLabel(
          AppLocalizations(const Locale('es')),
          const BonusInfo(type: 'bleed', bonusPct: 100),
        ),
        '+100%',
      );
      expect(
        formatBonusLabel(
          AppLocalizations(const Locale('es')),
          const BonusInfo(type: 'poison', bonusPct: 75),
          dim: true,
        ),
        '-75%',
      );
    });
  });
}
