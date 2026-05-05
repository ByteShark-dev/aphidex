import '../models/enemy.dart';

class EnemyListEntry {
  final String speciesKey;
  final List<Enemy> variants;

  const EnemyListEntry({required this.speciesKey, required this.variants});

  Enemy variantForGame(String game) {
    return variants.firstWhere(
      (enemy) => enemy.game == game,
      orElse: () => variants.first,
    );
  }

  Enemy preferredVariant({String? preferredGame, bool preferG2Default = true}) {
    if (preferredGame != null) {
      final matching = variants.where((enemy) => enemy.game == preferredGame);
      if (matching.isNotEmpty) {
        return matching.first;
      }
    }

    if (preferG2Default) {
      final g2 = variants.where((enemy) => enemy.game == 'g2');
      if (g2.isNotEmpty) {
        return g2.first;
      }
    }

    final g1 = variants.where((enemy) => enemy.game == 'g1');
    if (g1.isNotEmpty) {
      return g1.first;
    }

    return variants.first;
  }

  Enemy sortVariant() {
    final g1 = variants.where((enemy) => enemy.game == 'g1');
    if (g1.isNotEmpty) {
      return g1.first;
    }

    return variants.reduce((best, current) {
      final bestOrder = best.order ?? 999999;
      final currentOrder = current.order ?? 999999;
      if (currentOrder < bestOrder) {
        return current;
      }
      return best;
    });
  }
}

List<EnemyListEntry> groupEnemyListEntries(
  List<Enemy> enemies, {
  required bool mergeSharedSpecies,
}) {
  if (!mergeSharedSpecies) {
    return enemies
        .map(
          (enemy) => EnemyListEntry(speciesKey: enemy.speciesKey, variants: [enemy]),
        )
        .toList();
  }

  final grouped = <String, List<Enemy>>{};
  for (final enemy in enemies) {
    grouped.putIfAbsent(enemy.speciesKey, () => <Enemy>[]).add(enemy);
  }

  return grouped.entries
      .map(
        (entry) => EnemyListEntry(
          speciesKey: entry.key,
          variants: entry.value
            ..sort((a, b) {
              if (a.game == b.game) {
                return (a.order ?? 999999).compareTo(b.order ?? 999999);
              }
              if (a.game == 'g1') {
                return -1;
              }
              if (b.game == 'g1') {
                return 1;
              }
              return a.game.compareTo(b.game);
            }),
        ),
      )
      .toList();
}
