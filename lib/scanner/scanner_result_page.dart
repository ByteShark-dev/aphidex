import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import 'creature_scanner_service.dart';

enum ScannerResultAction { manualSearch, tryAnother }

class ScannerResultPage extends StatelessWidget {
  final List<CreatureScannerMatch> matches;
  final List<String> rawLabels;
  final List<String> rawWebEntities;
  final bool weak;
  final bool multiCreature;
  final bool showRecoveryActions;
  final Future<void> Function(CreatureScannerMatch match) onOpenMatch;

  const ScannerResultPage({
    super.key,
    required this.matches,
    required this.rawLabels,
    required this.rawWebEntities,
    this.weak = false,
    this.multiCreature = false,
    this.showRecoveryActions = false,
    required this.onOpenMatch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
              weak: weak,
              multiCreature: multiCreature,
              showRecoveryActions: showRecoveryActions,
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
                      previewEnemy.cardNormal,
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
                          previewEnemy.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_confidenceLabel(match.confidence)),
                        if (_availableGamesLabel(l10n, match) != null) ...[
                          const SizedBox(height: 6),
                          Text(_availableGamesLabel(l10n, match)!),
                        ],
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

  String? _availableGamesLabel(
    AppLocalizations l10n,
    CreatureScannerMatch match,
  ) {
    final games = match.variants.map((enemy) => enemy.game).toSet();
    if (!games.contains('g1') || !games.contains('g2')) {
      return null;
    }
    return l10n.scannerAvailableInBothGames;
  }
}

class _RawDetectionCard extends StatelessWidget {
  final List<String> rawLabels;
  final List<String> rawWebEntities;
  final bool weak;
  final bool multiCreature;
  final bool showRecoveryActions;

  const _RawDetectionCard({
    required this.rawLabels,
    required this.rawWebEntities,
    required this.weak,
    required this.multiCreature,
    required this.showRecoveryActions,
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
            if (weak) ...[
              Text(
                l10n.scannerApproximateResult,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
            ],
            if (multiCreature) ...[
              Text(l10n.scannerMultipleCreaturesMessage),
              const SizedBox(height: 10),
            ],
            Text(
              l10n.scannerDetectedLabelsTitle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              rawLabels.isEmpty
                  ? l10n.scannerNoDetectedLabels
                  : rawLabels.join(', '),
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
            if (showRecoveryActions) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      ScannerResultAction.manualSearch,
                    ),
                    icon: const Icon(Icons.search),
                    label: Text(l10n.scannerManualSearchAction),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, ScannerResultAction.tryAnother),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.scannerTryAnotherImageAction),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
