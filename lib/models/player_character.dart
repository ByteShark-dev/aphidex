import 'package:flutter/material.dart';

enum AphidexGame { grounded, groundedTwo }

enum PlayerCharacterType { fullBody, portrait }

class PlayerCharacterAvatarConfig {
  const PlayerCharacterAvatarConfig({
    required this.fit,
    required this.alignment,
    required this.scale,
    this.padding = EdgeInsets.zero,
  });

  final BoxFit fit;
  final Alignment alignment;
  final double scale;
  final EdgeInsets padding;
}

class PlayerCharacter {
  const PlayerCharacter({
    required this.id,
    required this.game,
    required this.assetPath,
    required this.type,
    required this.avatar,
    required this.selectorOrder,
  });

  final String id;
  final AphidexGame game;
  final String assetPath;
  final PlayerCharacterType type;
  final PlayerCharacterAvatarConfig avatar;
  final int selectorOrder;
}
