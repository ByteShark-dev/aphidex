import 'dart:convert';
import 'dart:io';

const _languages = ['es', 'en', 'ru'];
const _sourceFiles = {
  'g1': 'assets/data/enemies_g1.json',
  'g2': 'assets/data/enemies_g2.json',
};
const _outputRoot = 'assets/data/creatures';
const _indexFields = [
  'id',
  'speciesKey',
  'game',
  'name',
  'tier',
  'danger',
  'isBoss',
  'order',
  'defaultGold',
  'goldLinkId',
  'cardNormal',
  'cardGold',
  'weaknesses',
  'resistances',
  'temperament',
  'health',
  'collectionGroup',
];

void main() {
  final outputRoot = Directory(_outputRoot);
  if (outputRoot.existsSync()) {
    outputRoot.deleteSync(recursive: true);
  }

  final sources = <String, List<Map<String, dynamic>>>{};
  for (final entry in _sourceFiles.entries) {
    final file = File(entry.value);
    if (!file.existsSync()) {
      throw StateError('Missing source file: ${entry.value}');
    }

    final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    sources[entry.key] = decoded
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }

  for (final language in _languages) {
    final languageDir = Directory('$_outputRoot/$language');
    final detailsDir = Directory('${languageDir.path}/details');
    detailsDir.createSync(recursive: true);

    for (final source in sources.entries) {
      final index = <Map<String, dynamic>>[];

      for (final creature in source.value) {
        index.add(_buildIndexEntry(creature, language));
        final detail = _localizeValue(creature, language);
        final id = creature['id'] as String?;
        if (id == null || id.trim().isEmpty) {
          throw StateError(
            'Creature without id in ${_sourceFiles[source.key]}',
          );
        }
        _writeJson(File('${detailsDir.path}/$id.json'), detail);
      }

      _writeJson(File('${languageDir.path}/index_${source.key}.json'), index);
    }
  }
}

Map<String, dynamic> _buildIndexEntry(
  Map<String, dynamic> creature,
  String language,
) {
  final entry = <String, dynamic>{};
  for (final field in _indexFields) {
    if (!creature.containsKey(field)) {
      continue;
    }
    final value = creature[field];
    entry[field] = field == 'name' ? _localizeValue(value, language) : value;
  }
  return entry;
}

dynamic _localizeValue(dynamic value, String language) {
  if (value is List) {
    return value.map((item) => _localizeValue(item, language)).toList();
  }

  if (value is Map) {
    final map = value.cast<String, dynamic>();
    final keys = map.keys.toSet();
    final isLocalizedMap =
        keys.isNotEmpty &&
        keys.every(_languages.contains) &&
        keys.any(_languages.contains);

    if (isLocalizedMap) {
      for (final code in [language, 'es', 'en', 'ru']) {
        final localized = map[code];
        if (localized != null && localized.toString().trim().isNotEmpty) {
          return localized.toString();
        }
      }
      return '';
    }

    return {
      for (final entry in map.entries)
        entry.key: _localizeValue(entry.value, language),
    };
  }

  return value;
}

void _writeJson(File file, Object? data) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(data));
}
