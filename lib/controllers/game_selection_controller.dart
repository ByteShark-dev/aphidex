import 'package:flutter/foundation.dart';

import '../data/aphidex_view_state.dart';
import '../data/local_storage.dart';
import '../models/game_pick.dart';
import '../models/player_character.dart';

class GameSelectionController {
  GameSelectionController._() {
    final restored = AphidexViewState.fromStorageString(
      LocalStorage.getString(aphidexViewStateStorageKey),
    );
    gamePick.value = _gamePickFromIndex(
      restored?.gamePickIndex ??
          LocalStorage.getInt(_gamePickKey, fallback: GamePick.g1.index),
    );
    _lastConcreteGame = _concreteGameFromIndex(
      LocalStorage.getInt(_lastConcreteGameKey, fallback: GamePick.g1.index),
    );
    if (_isConcrete(gamePick.value)) {
      _lastConcreteGame = gamePick.value;
    }
  }

  static final GameSelectionController instance = GameSelectionController._();

  static const String _gamePickKey = 'ui_game_pick';
  static const String _lastConcreteGameKey = 'ui_last_concrete_game_pick';

  final ValueNotifier<GamePick> gamePick = ValueNotifier<GamePick>(GamePick.g1);
  late GamePick _lastConcreteGame;

  GamePick get lastConcreteGame => _lastConcreteGame;

  AphidexGame get profileGame => resolveProfileGame(
    gamePick: gamePick.value,
    lastConcreteGame: _lastConcreteGame,
  );

  Future<void> select(GamePick pick) async {
    _apply(pick);
    await LocalStorage.setInt(_gamePickKey, pick.index);
    if (_isConcrete(pick)) {
      await LocalStorage.setInt(_lastConcreteGameKey, pick.index);
    }
  }

  void syncFromApp(GamePick pick) {
    _apply(pick);
  }

  void reloadFromStorage() {
    gamePick.value = _gamePickFromIndex(
      LocalStorage.getInt(_gamePickKey, fallback: GamePick.g1.index),
    );
    _lastConcreteGame = _concreteGameFromIndex(
      LocalStorage.getInt(_lastConcreteGameKey, fallback: GamePick.g1.index),
    );
  }

  Future<void> reset() async {
    _lastConcreteGame = GamePick.g1;
    gamePick.value = GamePick.g1;
    await Future.wait([
      LocalStorage.remove(_gamePickKey),
      LocalStorage.remove(_lastConcreteGameKey),
    ]);
  }

  void _apply(GamePick pick) {
    if (_isConcrete(pick)) {
      _lastConcreteGame = pick;
    }
    gamePick.value = pick;
  }

  static AphidexGame resolveProfileGame({
    required GamePick gamePick,
    GamePick? lastConcreteGame,
  }) {
    final resolved = gamePick == GamePick.all
        ? lastConcreteGame ?? GamePick.g1
        : gamePick;
    return resolved == GamePick.g2
        ? AphidexGame.groundedTwo
        : AphidexGame.grounded;
  }

  static bool _isConcrete(GamePick pick) => pick != GamePick.all;

  static GamePick _gamePickFromIndex(int index) =>
      GamePick.values[index.clamp(0, GamePick.values.length - 1)];

  static GamePick _concreteGameFromIndex(int index) {
    final pick = _gamePickFromIndex(index);
    return pick == GamePick.all ? GamePick.g1 : pick;
  }
}
