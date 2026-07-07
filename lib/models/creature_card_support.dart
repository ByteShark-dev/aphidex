enum CreatureCardVariant { normal, gold }

extension CreatureCardVariantX on CreatureCardVariant {
  String get storageValue => switch (this) {
    CreatureCardVariant.normal => 'normal',
    CreatureCardVariant.gold => 'gold',
  };

  static CreatureCardVariant? fromStorageValue(String? value) {
    return switch (value?.trim()) {
      'normal' => CreatureCardVariant.normal,
      'gold' => CreatureCardVariant.gold,
      _ => null,
    };
  }
}

abstract class CreatureCardCarrier {
  String get game;
  String get id;
  String? get goldLinkId;
  bool get defaultGold;
  bool get hasCreatureCard;
  bool get hasGoldCreatureCard;
  bool get hasSelectableCardVariants;
  CreatureCardVariant? get defaultCardVariant;
  String? assetForCardVariant(CreatureCardVariant variant);
}
