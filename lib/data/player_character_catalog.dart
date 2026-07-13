import 'package:flutter/material.dart';

import '../models/player_character.dart';

class PlayerCharacterCatalog {
  PlayerCharacterCatalog._();

  static const List<PlayerCharacter> all = [
    PlayerCharacter(
      id: 'g1_max',
      game: AphidexGame.grounded,
      assetPath: 'assets/images/player_characters/g1_max.png',
      type: PlayerCharacterType.fullBody,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment(0, -0.24),
        scale: 1.35,
      ),
      selectorOrder: 0,
    ),
    PlayerCharacter(
      id: 'g1_willow',
      game: AphidexGame.grounded,
      assetPath: 'assets/images/player_characters/g1_willow.png',
      type: PlayerCharacterType.fullBody,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment(0, -0.18),
        scale: 1.28,
      ),
      selectorOrder: 1,
    ),
    PlayerCharacter(
      id: 'g1_pete',
      game: AphidexGame.grounded,
      assetPath: 'assets/images/player_characters/g1_pete.png',
      type: PlayerCharacterType.fullBody,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment(0, -0.2),
        scale: 1.32,
      ),
      selectorOrder: 2,
    ),
    PlayerCharacter(
      id: 'g1_hoops',
      game: AphidexGame.grounded,
      assetPath: 'assets/images/player_characters/g1_hoops.png',
      type: PlayerCharacterType.fullBody,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment(0, -0.24),
        scale: 1.3,
      ),
      selectorOrder: 3,
    ),
    PlayerCharacter(
      id: 'g1_burgl',
      game: AphidexGame.grounded,
      assetPath: 'assets/images/player_characters/g1_burgl.png',
      type: PlayerCharacterType.portrait,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment(0, -0.08),
        scale: 1.3,
      ),
      selectorOrder: 4,
    ),
    PlayerCharacter(
      id: 'g1_wendell',
      game: AphidexGame.grounded,
      assetPath: 'assets/images/player_characters/g1_wendell.png',
      type: PlayerCharacterType.portrait,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        scale: 1.3,
      ),
      selectorOrder: 5,
    ),
    PlayerCharacter(
      id: 'g2_max',
      game: AphidexGame.groundedTwo,
      assetPath: 'assets/images/player_characters/g2_max.png',
      type: PlayerCharacterType.fullBody,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        scale: 1.14,
      ),
      selectorOrder: 0,
    ),
    PlayerCharacter(
      id: 'g2_willow',
      game: AphidexGame.groundedTwo,
      assetPath: 'assets/images/player_characters/g2_willow.png',
      type: PlayerCharacterType.fullBody,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        scale: 1.15,
      ),
      selectorOrder: 1,
    ),
    PlayerCharacter(
      id: 'g2_pete',
      game: AphidexGame.groundedTwo,
      assetPath: 'assets/images/player_characters/g2_pete.png',
      type: PlayerCharacterType.fullBody,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        scale: 1.18,
      ),
      selectorOrder: 2,
    ),
    PlayerCharacter(
      id: 'g2_hoops',
      game: AphidexGame.groundedTwo,
      assetPath: 'assets/images/player_characters/g2_hoops.png',
      type: PlayerCharacterType.fullBody,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        scale: 1.16,
      ),
      selectorOrder: 3,
    ),
    PlayerCharacter(
      id: 'g2_masked_stranger',
      game: AphidexGame.groundedTwo,
      assetPath: 'assets/images/player_characters/g2_masked_stranger.png',
      type: PlayerCharacterType.portrait,
      avatar: PlayerCharacterAvatarConfig(
        fit: BoxFit.cover,
        alignment: Alignment(0, -0.75),
        scale: 1.45,
      ),
      selectorOrder: 4,
    ),
  ];

  static List<PlayerCharacter> forGame(AphidexGame game) =>
      all.where((character) => character.game == game).toList()
        ..sort((a, b) => a.selectorOrder.compareTo(b.selectorOrder));

  static PlayerCharacter? byId(String? id) {
    if (id == null) {
      return null;
    }
    for (final character in all) {
      if (character.id == id) {
        return character;
      }
    }
    return null;
  }
}
