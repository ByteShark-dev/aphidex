import 'package:flutter/foundation.dart';

import '../data/local_storage.dart';

class PlayerDisplayNameController {
  PlayerDisplayNameController._() {
    reloadFromStorage();
  }

  static final PlayerDisplayNameController instance =
      PlayerDisplayNameController._();

  static const storageKey = 'playerDisplayName';
  static const maxLength = 24;

  final ValueNotifier<String> displayName = ValueNotifier<String>('');

  Future<void> save(String value) async {
    final normalized = normalize(value);
    displayName.value = normalized;
    if (normalized.isEmpty) {
      await LocalStorage.remove(storageKey);
      return;
    }
    await LocalStorage.setString(storageKey, normalized);
  }

  void reloadFromStorage() {
    displayName.value = normalize(LocalStorage.getString(storageKey) ?? '');
  }

  static String normalize(String value) {
    final trimmed = value.trim();
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }
}
