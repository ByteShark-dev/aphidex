import 'package:flutter/foundation.dart';
import '../data/local_storage.dart';

class FavoritesController {
  FavoritesController._() {
    favorites.value = LocalStorage.getStringSet(_key);
  }
  static final FavoritesController instance = FavoritesController._();

  static const String _key = 'favorites';

  final ValueNotifier<Set<String>> favorites = ValueNotifier<Set<String>>(
    <String>{},
  );

  bool isFavorite(String id) => favorites.value.contains(id);

  Future<void> toggle(String id) async {
    final s = Set<String>.from(favorites.value);
    if (s.contains(id)) {
      s.remove(id);
    } else {
      s.add(id);
    }
    favorites.value = s;
    await LocalStorage.setStringSet(_key, s);
  }

  Future<void> reset() async {
    favorites.value = <String>{};
    await LocalStorage.setStringSet(_key, favorites.value);
  }
}
