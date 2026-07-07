import 'dart:convert';

import '../models/creature_card_support.dart';

enum CreatureCardProgress { unowned, obtained, gold }

extension CreatureCardProgressX on CreatureCardProgress {
  String get storageValue => switch (this) {
    CreatureCardProgress.unowned => 'unowned',
    CreatureCardProgress.obtained => 'obtained',
    CreatureCardProgress.gold => 'gold',
  };

  static CreatureCardProgress? fromStorageValue(String? value) {
    return switch (value?.trim()) {
      'unowned' => CreatureCardProgress.unowned,
      'obtained' => CreatureCardProgress.obtained,
      'gold' => CreatureCardProgress.gold,
      _ => null,
    };
  }
}

typedef CreatureCardProgressMap = Map<String, CreatureCardProgress>;

const String creatureCardProgressStorageKey = 'creature_card_progress_v2';

String creatureCardProgressKey(CreatureCardCarrier enemy) =>
    '${enemy.game}:${enemy.id}';

CreatureCardProgressMap decodeCreatureCardProgressMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return <String, CreatureCardProgress>{};
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, CreatureCardProgress>{};
    }

    final entries = <String, CreatureCardProgress>{};
    for (final entry in decoded.entries) {
      final progress = CreatureCardProgressX.fromStorageValue(
        entry.value?.toString(),
      );
      if (progress == null) {
        continue;
      }
      entries[entry.key.toString()] = progress;
    }
    return entries;
  } catch (_) {
    return <String, CreatureCardProgress>{};
  }
}

String encodeCreatureCardProgressMap(CreatureCardProgressMap value) {
  final encoded = <String, String>{};
  for (final entry in value.entries) {
    encoded[entry.key] = entry.value.storageValue;
  }
  return jsonEncode(encoded);
}

bool creatureCardHasNormalVariant(CreatureCardCarrier enemy) {
  return (enemy.assetForCardVariant(CreatureCardVariant.normal) ?? '')
      .trim()
      .isNotEmpty;
}

bool creatureCardHasGoldVariant(CreatureCardCarrier enemy) {
  return (enemy.assetForCardVariant(CreatureCardVariant.gold) ?? '')
      .trim()
      .isNotEmpty;
}

bool shouldTrackCreatureCardProgress(CreatureCardCarrier enemy) {
  return enemy.hasCreatureCard &&
      (creatureCardHasNormalVariant(enemy) ||
          creatureCardHasGoldVariant(enemy));
}

CreatureCardProgress normalizeCreatureCardProgress(
  CreatureCardCarrier enemy,
  CreatureCardProgress progress,
) {
  if (!shouldTrackCreatureCardProgress(enemy)) {
    return CreatureCardProgress.unowned;
  }

  final hasNormal = creatureCardHasNormalVariant(enemy);
  final hasGold = creatureCardHasGoldVariant(enemy);
  if (enemy.defaultGold) {
    if (hasGold) {
      return CreatureCardProgress.gold;
    }
    if (hasNormal) {
      return CreatureCardProgress.obtained;
    }
    return CreatureCardProgress.unowned;
  }

  switch (progress) {
    case CreatureCardProgress.unowned:
      return CreatureCardProgress.unowned;
    case CreatureCardProgress.obtained:
      if (hasNormal) {
        return CreatureCardProgress.obtained;
      }
      return CreatureCardProgress.unowned;
    case CreatureCardProgress.gold:
      if (hasGold) {
        return CreatureCardProgress.gold;
      }
      if (hasNormal) {
        return CreatureCardProgress.obtained;
      }
      return CreatureCardProgress.unowned;
  }
}

CreatureCardProgress nextCreatureCardProgress(
  CreatureCardCarrier enemy,
  CreatureCardProgress current,
) {
  final normalized = normalizeCreatureCardProgress(enemy, current);
  final hasNormal = creatureCardHasNormalVariant(enemy);
  final hasGold = creatureCardHasGoldVariant(enemy);

  if (enemy.defaultGold) {
    return normalized;
  }
  if (!hasNormal && !hasGold) {
    return CreatureCardProgress.unowned;
  }
  if (hasNormal && hasGold) {
    return switch (normalized) {
      CreatureCardProgress.unowned => CreatureCardProgress.obtained,
      CreatureCardProgress.obtained => CreatureCardProgress.gold,
      CreatureCardProgress.gold => CreatureCardProgress.unowned,
    };
  }
  if (hasNormal) {
    return switch (normalized) {
      CreatureCardProgress.unowned => CreatureCardProgress.obtained,
      CreatureCardProgress.obtained ||
      CreatureCardProgress.gold => CreatureCardProgress.unowned,
    };
  }
  return switch (normalized) {
    CreatureCardProgress.unowned ||
    CreatureCardProgress.obtained => CreatureCardProgress.gold,
    CreatureCardProgress.gold => CreatureCardProgress.unowned,
  };
}

CreatureCardProgress migrateLegacyCreatureCardProgress(
  CreatureCardCarrier enemy,
  Set<String> legacyGoldIds,
) {
  if (!shouldTrackCreatureCardProgress(enemy)) {
    return CreatureCardProgress.unowned;
  }
  if (enemy.defaultGold) {
    return normalizeCreatureCardProgress(enemy, CreatureCardProgress.gold);
  }

  final linkedIds = <String>{
    enemy.id.trim(),
    if (enemy.goldLinkId != null) enemy.goldLinkId!.trim(),
  }..removeWhere((value) => value.isEmpty);
  final hadLegacyGold = linkedIds.any(legacyGoldIds.contains);
  if (!hadLegacyGold) {
    return CreatureCardProgress.unowned;
  }

  final hasNormal = creatureCardHasNormalVariant(enemy);
  final hasGold = creatureCardHasGoldVariant(enemy);
  if (hasGold) {
    return CreatureCardProgress.gold;
  }
  if (hasNormal) {
    return CreatureCardProgress.obtained;
  }
  return CreatureCardProgress.unowned;
}

CreatureCardProgress resolveCreatureCardProgress(
  CreatureCardCarrier enemy,
  CreatureCardProgressMap progressByKey, {
  Set<String> legacyGoldIds = const <String>{},
}) {
  if (!shouldTrackCreatureCardProgress(enemy)) {
    return CreatureCardProgress.unowned;
  }

  final stored = progressByKey[creatureCardProgressKey(enemy)];
  if (stored != null) {
    return normalizeCreatureCardProgress(enemy, stored);
  }
  return migrateLegacyCreatureCardProgress(enemy, legacyGoldIds);
}

CreatureCardVariant? resolveCreatureCardVariant(
  CreatureCardCarrier enemy,
  CreatureCardProgress progress,
) {
  if (!shouldTrackCreatureCardProgress(enemy)) {
    return null;
  }

  final normalized = normalizeCreatureCardProgress(enemy, progress);
  if (normalized == CreatureCardProgress.gold &&
      creatureCardHasGoldVariant(enemy)) {
    return CreatureCardVariant.gold;
  }
  if (creatureCardHasNormalVariant(enemy)) {
    return CreatureCardVariant.normal;
  }
  if (creatureCardHasGoldVariant(enemy)) {
    return CreatureCardVariant.gold;
  }
  return null;
}

String? resolveCreatureCardAsset(
  CreatureCardCarrier enemy,
  CreatureCardProgress progress,
) {
  final variant = resolveCreatureCardVariant(enemy, progress);
  if (variant == null) {
    return null;
  }
  return enemy.assetForCardVariant(variant);
}
