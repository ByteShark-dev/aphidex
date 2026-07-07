import 'package:aphidex/data/creature_card_state.dart';
import 'package:aphidex/models/creature_card_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal plus gold cards cycle through all three approved states', () {
    const enemy = _FakeCardCarrier(
      id: 'regular',
      cardNormal: 'normal.webp',
      cardGold: 'gold.webp',
    );

    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.unowned),
      CreatureCardProgress.obtained,
    );
    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.obtained),
      CreatureCardProgress.gold,
    );
    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.gold),
      CreatureCardProgress.unowned,
    );
  });

  test('normal-only cards skip the gold state', () {
    const enemy = _FakeCardCarrier(
      id: 'normal_only',
      cardNormal: 'normal.webp',
    );

    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.unowned),
      CreatureCardProgress.obtained,
    );
    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.obtained),
      CreatureCardProgress.unowned,
    );
  });

  test('gold-only cards toggle between unowned and gold', () {
    const enemy = _FakeCardCarrier(id: 'gold_only', cardGold: 'gold.webp');

    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.unowned),
      CreatureCardProgress.gold,
    );
    expect(
      nextCreatureCardProgress(enemy, CreatureCardProgress.gold),
      CreatureCardProgress.unowned,
    );
  });

  test('entries without cards stay out of the progress system', () {
    const enemy = _FakeCardCarrier(id: 'global_entry');

    expect(shouldTrackCreatureCardProgress(enemy), isFalse);
    expect(
      resolveCreatureCardProgress(
        enemy,
        const <String, CreatureCardProgress>{},
      ),
      CreatureCardProgress.unowned,
    );
    expect(resolveCreatureCardAsset(enemy, CreatureCardProgress.gold), isNull);
  });
}

class _FakeCardCarrier implements CreatureCardCarrier {
  const _FakeCardCarrier({
    required this.id,
    this.cardNormal = '',
    this.cardGold = '',
  });

  @override
  final String id;
  final String cardNormal;
  final String cardGold;

  @override
  bool get defaultGold => false;

  @override
  String get game => 'g2';

  @override
  String? get goldLinkId => null;

  @override
  bool get hasCreatureCard => cardNormal.isNotEmpty || cardGold.isNotEmpty;

  @override
  bool get hasGoldCreatureCard => cardGold.isNotEmpty;

  @override
  bool get hasSelectableCardVariants =>
      cardNormal.isNotEmpty && cardGold.isNotEmpty;

  @override
  CreatureCardVariant? get defaultCardVariant {
    if (cardNormal.isNotEmpty) {
      return CreatureCardVariant.normal;
    }
    if (cardGold.isNotEmpty) {
      return CreatureCardVariant.gold;
    }
    return null;
  }

  @override
  String? assetForCardVariant(CreatureCardVariant variant) {
    return switch (variant) {
      CreatureCardVariant.normal => cardNormal.isEmpty ? null : cardNormal,
      CreatureCardVariant.gold => cardGold.isEmpty ? null : cardGold,
    };
  }
}
