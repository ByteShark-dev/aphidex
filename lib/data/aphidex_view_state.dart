import 'dart:convert';

const String aphidexViewStateStorageKey = 'ui_view_state_v1';

class AphidexViewState {
  final int version;
  final int gamePickIndex;
  final int sortModeIndex;
  final bool sortDescending;
  final String query;
  final bool filterFavorites;
  final bool filterGold;
  final Set<String> tierFilters;
  final Set<String> classFilters;
  final Set<String> dangerFilters;
  final String? selectedSpeciesKey;
  final String? detailEnemyId;
  final String? detailGame;
  final bool detailOpen;
  final double listScrollOffset;

  const AphidexViewState({
    this.version = 1,
    required this.gamePickIndex,
    required this.sortModeIndex,
    required this.sortDescending,
    required this.query,
    required this.filterFavorites,
    required this.filterGold,
    required this.tierFilters,
    required this.classFilters,
    required this.dangerFilters,
    required this.selectedSpeciesKey,
    required this.detailEnemyId,
    required this.detailGame,
    required this.detailOpen,
    required this.listScrollOffset,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'gamePickIndex': gamePickIndex,
      'sortModeIndex': sortModeIndex,
      'sortDescending': sortDescending,
      'query': query,
      'filterFavorites': filterFavorites,
      'filterGold': filterGold,
      'tierFilters': tierFilters.toList()..sort(),
      'classFilters': classFilters.toList()..sort(),
      'dangerFilters': dangerFilters.toList()..sort(),
      if (selectedSpeciesKey != null) 'selectedSpeciesKey': selectedSpeciesKey,
      if (detailEnemyId != null) 'detailEnemyId': detailEnemyId,
      if (detailGame != null) 'detailGame': detailGame,
      'detailOpen': detailOpen,
      'listScrollOffset': listScrollOffset,
    };
  }

  String toStorageString() => jsonEncode(toJson());

  AphidexViewState copyWith({
    int? version,
    int? gamePickIndex,
    int? sortModeIndex,
    bool? sortDescending,
    String? query,
    bool? filterFavorites,
    bool? filterGold,
    Set<String>? tierFilters,
    Set<String>? classFilters,
    Set<String>? dangerFilters,
    String? selectedSpeciesKey,
    String? detailEnemyId,
    String? detailGame,
    bool? detailOpen,
    double? listScrollOffset,
  }) {
    return AphidexViewState(
      version: version ?? this.version,
      gamePickIndex: gamePickIndex ?? this.gamePickIndex,
      sortModeIndex: sortModeIndex ?? this.sortModeIndex,
      sortDescending: sortDescending ?? this.sortDescending,
      query: query ?? this.query,
      filterFavorites: filterFavorites ?? this.filterFavorites,
      filterGold: filterGold ?? this.filterGold,
      tierFilters: tierFilters ?? this.tierFilters,
      classFilters: classFilters ?? this.classFilters,
      dangerFilters: dangerFilters ?? this.dangerFilters,
      selectedSpeciesKey: selectedSpeciesKey ?? this.selectedSpeciesKey,
      detailEnemyId: detailEnemyId ?? this.detailEnemyId,
      detailGame: detailGame ?? this.detailGame,
      detailOpen: detailOpen ?? this.detailOpen,
      listScrollOffset: listScrollOffset ?? this.listScrollOffset,
    );
  }

  static AphidexViewState? fromStorageString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return AphidexViewState.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  factory AphidexViewState.fromJson(Map<String, dynamic> json) {
    Set<String> parseSet(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw.map((item) => item.toString()).toSet();
      }
      return <String>{};
    }

    double parseOffset(Object? raw) {
      if (raw is num) {
        return raw.toDouble();
      }
      return 0;
    }

    return AphidexViewState(
      version: json['version'] is int ? json['version'] as int : 1,
      gamePickIndex: json['gamePickIndex'] is int
          ? json['gamePickIndex'] as int
          : 0,
      sortModeIndex: json['sortModeIndex'] is int
          ? json['sortModeIndex'] as int
          : 0,
      sortDescending: json['sortDescending'] as bool? ?? false,
      query: json['query'] as String? ?? '',
      filterFavorites: json['filterFavorites'] as bool? ?? false,
      filterGold: json['filterGold'] as bool? ?? false,
      tierFilters: parseSet('tierFilters'),
      classFilters: parseSet('classFilters'),
      dangerFilters: parseSet('dangerFilters'),
      selectedSpeciesKey: json['selectedSpeciesKey'] as String?,
      detailEnemyId: json['detailEnemyId'] as String?,
      detailGame: json['detailGame'] as String?,
      detailOpen: json['detailOpen'] as bool? ?? false,
      listScrollOffset: parseOffset(json['listScrollOffset']),
    );
  }
}
