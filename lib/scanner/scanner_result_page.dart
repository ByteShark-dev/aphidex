import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import 'creature_scanner_service.dart';

class ScannerResultPage extends StatelessWidget {
  final List<CreatureScannerMatch> matches;
  final List<String> rawLabels;
  final List<String> rawWebEntities;
  final Future<void> Function(CreatureScannerMatch match) onOpenMatch;

  const ScannerResultPage({
    super.key,
    required this.matches,
    required this.rawLabels,
    required this.rawWebEntities,
    required this.onOpenMatch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = l10n.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scannerPossibleCreaturesTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: matches.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _RawDetectionCard(
              rawLabels: rawLabels,
              rawWebEntities: rawWebEntities,
            );
          }

          final match = matches[index - 1];
          final previewEnemy = match.previewEnemy;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      previewEnemy.photo,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          previewEnemy.name.resolve(languageCode),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_confidenceLabel(match.confidence)),
                        const SizedBox(height: 6),
                        Text(match.sourceLabels.join(', ')),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => onOpenMatch(match),
                          child: Text(l10n.openAction),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _confidenceLabel(double value) {
    final percent = (value * 100).round().clamp(0, 100);
    return '$percent%';
  }
}

class _RawDetectionCard extends StatelessWidget {
  final List<String> rawLabels;
  final List<String> rawWebEntities;

  const _RawDetectionCard({
    required this.rawLabels,
    required this.rawWebEntities,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.scannerDetectedLabelsTitle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              rawLabels.isEmpty ? l10n.scannerNoDetectedLabels : rawLabels.join(', '),
            ),
            if (rawWebEntities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                l10n.scannerDetectedWebTitle,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(rawWebEntities.join(', ')),
            ],
          ],
        ),
      ),
    );
  }
}
