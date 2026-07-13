import 'package:flutter/foundation.dart';

import '../data/local_storage.dart';
import '../data/player_character_catalog.dart';
import '../models/player_character.dart';

class PlayerProfileController {
  PlayerProfileController._() {
    reloadFromStorage();
  }

  static final PlayerProfileController instance = PlayerProfileController._();

  static const _groundedKey = 'selectedGroundedCharacterId';
  static const _groundedTwoKey = 'selectedGrounded2CharacterId';
  static const _legacyGroundedKey = 'player_profile_g1';
  static const _legacyGroundedTwoKey = 'player_profile_g2';

  final ValueNotifier<Map<AphidexGame, String?>> selections =
      ValueNotifier<Map<AphidexGame, String?>>(_emptySelections());

  String? selectedIdFor(AphidexGame game) => selections.value[game];

  PlayerCharacter? selectedCharacterFor(AphidexGame game) =>
      PlayerCharacterCatalog.byId(selectedIdFor(game));

  Future<void> select(AphidexGame game, String characterId) async {
    final character = PlayerCharacterCatalog.byId(characterId);
    if (character == null || character.game != game) {
      throw ArgumentError.value(characterId, 'characterId');
    }
    _setSelection(game, character.id);
    await LocalStorage.setString(_storageKeyFor(game), character.id);
  }

  Future<void> clear(AphidexGame game) async {
    _setSelection(game, null);
    await LocalStorage.remove(_storageKeyFor(game));
  }

  void reloadFromStorage() {
    selections.value = {
      AphidexGame.grounded: _validStoredId(AphidexGame.grounded),
      AphidexGame.groundedTwo: _validStoredId(AphidexGame.groundedTwo),
    };
  }

  void _setSelection(AphidexGame game, String? id) {
    selections.value = {...selections.value, game: id};
  }

  String? _validStoredId(AphidexGame game) {
    final stored =
        LocalStorage.getString(_storageKeyFor(game)) ??
        LocalStorage.getString(_legacyStorageKeyFor(game));
    final character = PlayerCharacterCatalog.byId(stored);
    return character?.game == game ? character?.id : null;
  }

  static Map<AphidexGame, String?> _emptySelections() => {
    AphidexGame.grounded: null,
    AphidexGame.groundedTwo: null,
  };

  static String _storageKeyFor(AphidexGame game) => switch (game) {
    AphidexGame.grounded => _groundedKey,
    AphidexGame.groundedTwo => _groundedTwoKey,
  };

  static String _legacyStorageKeyFor(AphidexGame game) => switch (game) {
    AphidexGame.grounded => _legacyGroundedKey,
    AphidexGame.groundedTwo => _legacyGroundedTwoKey,
  };
}
