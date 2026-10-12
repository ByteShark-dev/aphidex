import 'package:flutter/foundation.dart';

import '../data/local_storage.dart';

class CombatRecommendationPreferencesController {
  static const countKey = 'weaponRecommendationCount';
  static const onboardingKey = 'weaponRecommendationOnboardingShown';
  static final instance = CombatRecommendationPreferencesController._();

  final ValueNotifier<int> weaponRecommendationCount = ValueNotifier(5);
  final ValueNotifier<bool> onboardingShown = ValueNotifier(false);
  bool _loaded = false;

  CombatRecommendationPreferencesController._();

  void load() {
    if (_loaded) return;
    _loaded = true;
    weaponRecommendationCount.value = LocalStorage.getInt(
      countKey,
      fallback: 5,
    ).clamp(3, 8);
    onboardingShown.value = LocalStorage.getBool(onboardingKey);
  }

  Future<void> setCount(int value) async {
    load();
    final normalized = value.clamp(3, 8);
    weaponRecommendationCount.value = normalized;
    await LocalStorage.setInt(countKey, normalized);
  }

  Future<void> markOnboardingShown() async {
    load();
    onboardingShown.value = true;
    await LocalStorage.setBool(onboardingKey, true);
  }

  Future<void> reset() async {
    weaponRecommendationCount.value = 5;
    onboardingShown.value = false;
    await LocalStorage.remove(countKey);
    await LocalStorage.remove(onboardingKey);
  }
}
