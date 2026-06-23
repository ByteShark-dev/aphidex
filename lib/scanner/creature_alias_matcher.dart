import 'dart:math' as math;

class CreatureAliasMatch {
  final String creatureId;
  final String displayName;
  final double confidence;
  final List<String> sourceLabels;

  const CreatureAliasMatch({
    required this.creatureId,
    required this.displayName,
    required this.confidence,
    required this.sourceLabels,
  });
}

class CreatureAliasMatcherResult {
  final List<CreatureAliasMatch> matches;
  final List<String> rawLabels;
  final List<String> rawWebEntities;

  const CreatureAliasMatcherResult({
    required this.matches,
    required this.rawLabels,
    required this.rawWebEntities,
  });
}

class CreatureAliasMatcher {
  static const int maxMatches = 5;
  static const double minimumScore = 0.18;
  static const double clearMatchThreshold = 0.62;
  static const double clearMatchGap = 0.16;

  static const Set<String> _weakAliases = {
    'ant',
    'spider',
    'larva',
    'insect',
    'bug',
    'snake',
    'snail',
    'butterfly',
  };

  static const List<_AliasEntry> _entries = [
    _AliasEntry(
      creatureId: 'ladybug',
      speciesKey: 'ladybug',
      displayName: 'Ladybug',
      aliases: ['ladybug', 'lady bird', 'ladybird', 'mariquita'],
    ),
    _AliasEntry(
      creatureId: 'red_worker_ant',
      speciesKey: 'red_worker_ant',
      displayName: 'Red Worker Ant',
      aliases: [
        'red ant',
        'red worker ant',
        'hormiga roja',
        'hormiga obrera roja',
        'ant',
      ],
    ),
    _AliasEntry(
      creatureId: 'black_worker_ant',
      speciesKey: 'black_worker_ant',
      displayName: 'Black Worker Ant',
      aliases: [
        'black ant',
        'black worker ant',
        'hormiga negra',
        'hormiga obrera negra',
      ],
    ),
    _AliasEntry(
      creatureId: 'fire_worker_ant',
      speciesKey: 'g1_fire_worker_ant',
      displayName: 'Fire Worker Ant',
      aliases: [
        'fire ant',
        'fire worker ant',
        'hormiga de fuego',
        'hormiga obrera de fuego',
      ],
    ),
    _AliasEntry(
      creatureId: 'red_soldier_ant',
      speciesKey: 'red_soldier_ant',
      displayName: 'Red Soldier Ant',
      aliases: ['red soldier ant', 'hormiga soldado roja'],
    ),
    _AliasEntry(
      creatureId: 'black_soldier_ant',
      speciesKey: 'black_soldier_ant',
      displayName: 'Black Soldier Ant',
      aliases: ['black soldier ant', 'hormiga soldado negra'],
    ),
    _AliasEntry(
      creatureId: 'bee',
      speciesKey: 'bee',
      displayName: 'Bee',
      aliases: ['bee', 'abeja'],
    ),
    _AliasEntry(
      creatureId: 'wasp',
      speciesKey: 'wasp',
      displayName: 'Wasp',
      aliases: ['wasp', 'avispa'],
    ),
    _AliasEntry(
      creatureId: 'wasp_drone',
      speciesKey: 'wasp_drone',
      displayName: 'Wasp Drone',
      aliases: ['wasp drone', 'drone wasp', 'avispa zángano', 'avispa zangano'],
    ),
    _AliasEntry(
      creatureId: 'mosquito',
      speciesKey: 'mosquito',
      displayName: 'Mosquito',
      aliases: ['mosquito'],
    ),
    _AliasEntry(
      creatureId: 'gnat',
      speciesKey: 'gnat',
      displayName: 'Gnat',
      aliases: [
        'gnat',
        'mosquito pequeño',
        'mosquito pequeno',
        'jejen',
        'jején',
      ],
    ),
    _AliasEntry(
      creatureId: 'aphid',
      speciesKey: 'aphid',
      displayName: 'Aphid',
      aliases: ['aphid', 'pulgón', 'pulgon'],
    ),
    _AliasEntry(
      creatureId: 'woolly_aphid',
      speciesKey: 'woolly_aphid',
      displayName: 'Woolly Aphid',
      aliases: ['woolly aphid', 'pulgón lanudo', 'pulgon lanudo'],
    ),
    _AliasEntry(
      creatureId: 'weevil',
      speciesKey: 'weevil',
      displayName: 'Weevil',
      aliases: ['weevil', 'gorgojo'],
    ),
    _AliasEntry(
      creatureId: 'grub',
      speciesKey: 'grub',
      displayName: 'Grub',
      aliases: [
        'grub',
        'larva subterránea',
        'larva subterranea',
        'gusano blanco',
        'larva',
      ],
    ),
    _AliasEntry(
      creatureId: 'larva',
      speciesKey: 'larva',
      displayName: 'Larva',
      aliases: ['larva'],
    ),
    _AliasEntry(
      creatureId: 'mite',
      speciesKey: 'lawn_mite',
      displayName: 'Lawn Mite',
      aliases: [
        'mite',
        'lawn mite',
        'ácaro',
        'acaro',
        'ácaro de césped',
        'acaro de cesped',
      ],
    ),
    _AliasEntry(
      creatureId: 'stinkbug',
      speciesKey: 'stinkbug',
      displayName: 'Stinkbug',
      aliases: ['stink bug', 'stinkbug', 'chinche apestosa', 'chinche'],
    ),
    _AliasEntry(
      creatureId: 'ladybird',
      speciesKey: 'g1_ladybird',
      displayName: 'Ladybird',
      aliases: ['ladybird', 'mariquita roja'],
    ),
    _AliasEntry(
      creatureId: 'ladybird_larva',
      speciesKey: 'g1_ladybird_larva',
      displayName: 'Ladybird Larva',
      aliases: ['ladybird larva', 'ladybug larva', 'larva de mariquita roja'],
    ),
    _AliasEntry(
      creatureId: 'blue_butterfly',
      speciesKey: 'blue_butterfly',
      displayName: 'Blue Butterfly',
      aliases: ['blue butterfly', 'butterfly', 'mariposa azul', 'mariposa'],
    ),
    _AliasEntry(
      creatureId: 'caterpillar',
      speciesKey: 'caterpillar',
      displayName: 'Caterpillar',
      aliases: ['caterpillar', 'oruga'],
    ),
    _AliasEntry(
      creatureId: 'cricket',
      speciesKey: 'cricket',
      displayName: 'Cricket',
      aliases: ['cricket', 'grillo'],
    ),
    _AliasEntry(
      creatureId: 'bombardier_beetle',
      speciesKey: 'bombardier_beetle',
      displayName: 'Bombardier Beetle',
      aliases: ['bombardier beetle', 'bombardier', 'escarabajo bombardero'],
    ),
    _AliasEntry(
      creatureId: 'potato_beetle',
      speciesKey: 'potato_beetle',
      displayName: 'Potato Beetle',
      aliases: [
        'potato beetle',
        'potato bug',
        'escarabajo de la patata',
        'escarabajo de la papa',
      ],
    ),
    _AliasEntry(
      creatureId: 'rust_beetle',
      speciesKey: 'rust_beetle',
      displayName: 'Rust Beetle',
      aliases: ['rust beetle', 'escarabajo oxidado'],
    ),
    _AliasEntry(
      creatureId: 'black_ox_beetle',
      speciesKey: 'g1_black_ox_beetle',
      displayName: 'Black Ox Beetle',
      aliases: ['black ox beetle', 'escarabajo buey negro'],
    ),
    _AliasEntry(
      creatureId: 'scarab',
      speciesKey: 'g1_scarab',
      displayName: 'Scarab',
      aliases: ['scarab', 'escarabajo'],
    ),
    _AliasEntry(
      creatureId: 'cockroach',
      speciesKey: 'cockroach',
      displayName: 'Cockroach',
      aliases: ['cockroach', 'cucaracha'],
    ),
    _AliasEntry(
      creatureId: 'cockroach_nymph',
      speciesKey: 'cockroach_nymph',
      displayName: 'Cockroach Nymph',
      aliases: ['cockroach nymph', 'nymph cockroach', 'ninfa de cucaracha'],
    ),
    _AliasEntry(
      creatureId: 'cockroach_queen',
      speciesKey: 'cockroach_queen',
      displayName: 'Cockroach Queen',
      aliases: [
        'cockroach queen',
        'queen cockroach',
        'reina cucaracha',
        'reina de las cucarachas',
      ],
    ),
    _AliasEntry(
      creatureId: 'orb_weaver',
      speciesKey: 'orb_weaver',
      displayName: 'Orb Weaver',
      aliases: [
        'orb weaver',
        'orb-weaver',
        'spider',
        'araña',
        'arana',
        'tejedora de orbe',
      ],
    ),
    _AliasEntry(
      creatureId: 'orb_weaver_jr',
      speciesKey: 'orb_weaver_jr',
      displayName: 'Orb Weaver Jr.',
      aliases: ['orb weaver jr', 'orb weaver junior', 'tejedora de orbe joven'],
    ),
    _AliasEntry(
      creatureId: 'wolf_spider',
      speciesKey: 'wolf_spider',
      displayName: 'Wolf Spider',
      aliases: ['wolf spider', 'araña lobo', 'arana lobo'],
    ),
    _AliasEntry(
      creatureId: 'spiderling',
      speciesKey: 'spiderling',
      displayName: 'Spiderling',
      aliases: ['spiderling', 'arañita', 'aranita'],
    ),
    _AliasEntry(
      creatureId: 'black_widow',
      speciesKey: 'g1_black_widow',
      displayName: 'Black Widow',
      aliases: ['black widow', 'viuda negra'],
    ),
    _AliasEntry(
      creatureId: 'black_widowling',
      speciesKey: 'g1_black_widowling',
      displayName: 'Black Widowling',
      aliases: [
        'black widowling',
        'cría de viuda negra',
        'cria de viuda negra',
      ],
    ),
    _AliasEntry(
      creatureId: 'pincher_earwig',
      speciesKey: 'pincher_earwig',
      displayName: 'Pincher Earwig',
      aliases: [
        'earwig',
        'pincher earwig',
        'tijerilla',
        'tijereta',
        'tijerilla pinza',
        'tijereta pinza',
      ],
    ),
    _AliasEntry(
      creatureId: 'whipper_earwig',
      speciesKey: 'whipper_earwig',
      displayName: 'Whipper Earwig',
      aliases: [
        'earwig',
        'whipper earwig',
        'tijerilla',
        'tijereta',
        'tijerilla látigo',
        'tijerilla latigo',
        'tijereta látigo',
        'tijereta latigo',
      ],
    ),
    _AliasEntry(
      creatureId: 'northern_scorpion',
      speciesKey: 'northern_scorpion',
      displayName: 'Northern Scorpion',
      aliases: [
        'scorpion',
        'northern scorpion',
        'escorpión',
        'escorpion',
        'escorpión del norte',
        'escorpion del norte',
      ],
    ),
    _AliasEntry(
      creatureId: 'northern_scorpling',
      speciesKey: 'northern_scorpling',
      displayName: 'Northern Scorpling',
      aliases: ['scorpling', 'northern scorpling', 'escorpling del norte'],
    ),
    _AliasEntry(
      creatureId: 'northern_scorpion_jr',
      speciesKey: 'northern_scorpion_jr',
      displayName: 'Northern Scorpion Jr.',
      aliases: [
        'northern scorpion jr',
        'northern scorpion young',
        'escorpión del norte joven',
        'escorpion del norte joven',
      ],
    ),
    _AliasEntry(
      creatureId: 'praying_mantis_nymph',
      speciesKey: 'praying_mantis_nymph',
      displayName: 'Praying Mantis Nymph',
      aliases: ['praying mantis nymph', 'mantis nymph', 'ninfa de mantis'],
    ),
    _AliasEntry(
      creatureId: 'firefly',
      speciesKey: 'firefly',
      displayName: 'Firefly',
      aliases: ['firefly', 'fire fly', 'luciérnaga', 'luciernaga'],
    ),
    _AliasEntry(
      creatureId: 'crow',
      speciesKey: 'crow',
      displayName: 'Crow',
      aliases: ['crow', 'cuervo'],
    ),
    _AliasEntry(
      creatureId: 'garter_snake',
      speciesKey: 'garter_snake',
      displayName: 'Garter Snake',
      aliases: ['garter snake', 'snake', 'serpiente de liga', 'serpiente'],
    ),
    _AliasEntry(
      creatureId: 'garden_snail',
      speciesKey: 'garden_snail',
      displayName: 'Garden Snail',
      aliases: [
        'garden snail',
        'snail',
        'caracol de jardín',
        'caracol de jardin',
        'caracol',
      ],
    ),
    _AliasEntry(
      creatureId: 'baby_garden_snail',
      speciesKey: 'baby_garden_snail',
      displayName: 'Baby Garden Snail',
      aliases: [
        'baby garden snail',
        'baby snail',
        'caracol bebé',
        'caracol bebe',
        'caracol de jardín bebé',
        'caracol de jardin bebe',
      ],
    ),
    _AliasEntry(
      creatureId: 'roly_poly',
      speciesKey: 'g1_roly_poly',
      displayName: 'Roly Poly',
      aliases: ['roly poly', 'pill bug', 'isopod', 'cochinilla'],
    ),
    _AliasEntry(
      creatureId: 'sickly_roly_poly',
      speciesKey: 'g1_sickly_roly_poly',
      displayName: 'Sickly Roly Poly',
      aliases: ['sickly roly poly', 'cochinilla enfermiza'],
    ),
    _AliasEntry(
      creatureId: 'antlion',
      speciesKey: 'g1_antlion',
      displayName: 'Antlion',
      aliases: ['antlion', 'hormiga león', 'hormiga leon'],
    ),
    _AliasEntry(
      creatureId: 'tick',
      speciesKey: 'g1_tick',
      displayName: 'Tick',
      aliases: ['tick', 'garrapata'],
    ),
    _AliasEntry(
      creatureId: 'tiger_mosquito',
      speciesKey: 'g1_tiger_mosquito',
      displayName: 'Tiger Mosquito',
      aliases: ['tiger mosquito', 'mosquito tigre'],
    ),
    _AliasEntry(
      creatureId: 'moth',
      speciesKey: 'g1_moth',
      displayName: 'Moth',
      aliases: ['moth', 'polilla'],
    ),
  ];

  const CreatureAliasMatcher();

  CreatureAliasMatcherResult match({
    required List<String> rawLabels,
    required List<String> rawWebEntities,
  }) {
    final normalizedLabels = _normalizeAll(rawLabels);
    final normalizedWebEntities = _normalizeAll(rawWebEntities);

    final results = <CreatureAliasMatch>[];
    for (final entry in _entries) {
      var score = 0.0;
      final matchedSources = <String>{};

      for (final alias in entry.aliases) {
        final normalizedAlias = _normalize(alias);
        final isWeakAlias = _weakAliases.contains(normalizedAlias);

        for (final raw in normalizedWebEntities) {
          final value = _scoreTermMatch(
            candidate: raw,
            alias: normalizedAlias,
            exactWeight: isWeakAlias ? 0.16 : 1.0,
            partialWeight: isWeakAlias ? 0.04 : 0.33,
          );
          if (value > 0) {
            score += value;
            matchedSources.add(raw);
          }
        }

        for (final raw in normalizedLabels) {
          final value = _scoreTermMatch(
            candidate: raw,
            alias: normalizedAlias,
            exactWeight: isWeakAlias ? 0.12 : 0.72,
            partialWeight: isWeakAlias ? 0.03 : 0.22,
          );
          if (value > 0) {
            score += value;
            matchedSources.add(raw);
          }
        }
      }

      if (score < minimumScore || matchedSources.isEmpty) {
        continue;
      }

      final confidence = math.min(score / 1.6, 1.0);
      results.add(
        CreatureAliasMatch(
          creatureId: entry.speciesKey,
          displayName: entry.displayName,
          confidence: confidence,
          sourceLabels: matchedSources.toList()..sort(),
        ),
      );
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return CreatureAliasMatcherResult(
      matches: results.take(maxMatches).toList(),
      rawLabels: normalizedLabels,
      rawWebEntities: normalizedWebEntities,
    );
  }

  bool isClearSingleMatch(List<CreatureAliasMatch> matches) {
    if (matches.isEmpty) {
      return false;
    }
    if (matches.length == 1) {
      return matches.first.confidence >= clearMatchThreshold;
    }
    return matches.first.confidence >= clearMatchThreshold &&
        (matches.first.confidence - matches[1].confidence) >= clearMatchGap;
  }

  static List<String> _normalizeAll(List<String> values) {
    final normalized =
        values.map(_normalize).where((item) => item.isNotEmpty).toSet().toList()
          ..sort();
    return normalized;
  }

  static double _scoreTermMatch({
    required String candidate,
    required String alias,
    required double exactWeight,
    required double partialWeight,
  }) {
    if (candidate == alias) {
      return exactWeight;
    }
    if (candidate.length < 4 || alias.length < 4) {
      return 0;
    }
    if (_containsWholePhrase(candidate, alias) ||
        _containsWholePhrase(alias, candidate)) {
      return partialWeight;
    }
    return 0;
  }

  static bool _containsWholePhrase(String value, String phrase) {
    final paddedValue = ' $value ';
    final paddedPhrase = ' $phrase ';
    return paddedValue.contains(paddedPhrase);
  }

  static String _normalize(String value) {
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'ã': 'a',
      'å': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'Ã¡': 'a',
      'Ã ': 'a',
      'Ã¤': 'a',
      'Ã¢': 'a',
      'Ã£': 'a',
      'Ã¥': 'a',
      'Ã©': 'e',
      'Ã¨': 'e',
      'Ã«': 'e',
      'Ãª': 'e',
      'Ã­': 'i',
      'Ã¬': 'i',
      'Ã¯': 'i',
      'Ã®': 'i',
      'Ã³': 'o',
      'Ã²': 'o',
      'Ã¶': 'o',
      'Ã´': 'o',
      'Ãµ': 'o',
      'Ãº': 'u',
      'Ã¹': 'u',
      'Ã¼': 'u',
      'Ã»': 'u',
      'Ã±': 'n',
      'ÃƒÂ¡': 'a',
      'ÃƒÂ ': 'a',
      'ÃƒÂ¤': 'a',
      'ÃƒÂ¢': 'a',
      'ÃƒÂ£': 'a',
      'ÃƒÂ¥': 'a',
      'ÃƒÂ©': 'e',
      'ÃƒÂ¨': 'e',
      'ÃƒÂ«': 'e',
      'ÃƒÂª': 'e',
      'ÃƒÂ­': 'i',
      'ÃƒÂ¬': 'i',
      'ÃƒÂ¯': 'i',
      'ÃƒÂ®': 'i',
      'ÃƒÂ³': 'o',
      'ÃƒÂ²': 'o',
      'ÃƒÂ¶': 'o',
      'ÃƒÂ´': 'o',
      'ÃƒÂµ': 'o',
      'ÃƒÂº': 'u',
      'ÃƒÂ¹': 'u',
      'ÃƒÂ¼': 'u',
      'ÃƒÂ»': 'u',
      'ÃƒÂ±': 'n',
    };

    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      if (replacements.containsKey(char)) {
        buffer.write(replacements[char]);
      } else if (char == '_' || char == '-') {
        buffer.write(' ');
      } else if (RegExp(r'[a-z0-9 ]').hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _AliasEntry {
  final String creatureId;
  final String speciesKey;
  final String displayName;
  final List<String> aliases;

  const _AliasEntry({
    required this.creatureId,
    required this.speciesKey,
    required this.displayName,
    required this.aliases,
  });
}
