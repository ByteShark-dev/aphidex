import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/local_storage.dart';
import '../i18n/app_localizations.dart';
import '../models/enemy_index_entry.dart';
import '../screens/enemy_detail_screen.dart';
import 'creature_alias_matcher.dart';
import 'creature_scanner_service.dart';
import 'scanner_result_page.dart';

typedef ScannerImagePicker = Future<XFile?> Function(ImageSource source);

class CreatureScannerComingSoonPage extends StatelessWidget {
  const CreatureScannerComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scannerTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.center_focus_strong,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.scannerComingSoonTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.scannerComingSoonMessage,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreatureScannerPage extends StatefulWidget {
  final List<EnemyIndexEntry> enemies;
  final String selectedGameScope;
  final CreatureScannerService? serviceOverride;
  final ScannerImagePicker? imagePickerOverride;

  const CreatureScannerPage({
    super.key,
    required this.enemies,
    required this.selectedGameScope,
    this.serviceOverride,
    this.imagePickerOverride,
  });

  @override
  State<CreatureScannerPage> createState() => _CreatureScannerPageState();
}

class _CreatureScannerPageState extends State<CreatureScannerPage> {
  late final CreatureScannerService _service;
  bool _isAnalyzing = false;
  String? _message;
  List<String> _lastRawLabels = const [];
  List<String> _lastRawWebEntities = const [];

  @override
  void initState() {
    super.initState();
    _service =
        widget.serviceOverride ??
        CreatureScannerService(
          provider: MlKitRecognitionProvider(),
          matcher: const CreatureAliasMatcher(),
          allEnemies: widget.enemies,
          selectedGameScope: widget.selectedGameScope,
        );
  }

  Future<void> _scan(ImageSource source) async {
    if (_isAnalyzing) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _message = null;
      _lastRawLabels = const [];
      _lastRawWebEntities = const [];
    });

    try {
      final file = await (widget.imagePickerOverride ?? _pickImage)(source);
      if (file == null) {
        return;
      }

      final result = await _service.scanFile(file);
      if (!mounted) {
        return;
      }

      setState(() {
        _lastRawLabels = result.rawLabels;
        _lastRawWebEntities = result.rawWebEntities;
      });

      if (result.matches.isEmpty) {
        setState(() => _message = context.l10n.scannerNoMatchMessage);
        return;
      }

      if (result.hasClearMatch && result.matches.length == 1) {
        await _openMatch(result.matches.first);
        return;
      }

      if (result.matches.length == 1) {
        setState(() => _message = context.l10n.scannerNoMatchMessage);
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScannerResultPage(
            matches: result.matches,
            rawLabels: result.rawLabels,
            rawWebEntities: result.rawWebEntities,
            onOpenMatch: _openMatch,
          ),
        ),
      );
    } on CreatureScannerException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _errorMessageFor(error.type, context.l10n);
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _isPermissionException(error)
            ? context.l10n.scannerPermissionDeniedMessage
            : context.l10n.scannerGenericErrorMessage;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _message = context.l10n.scannerGenericErrorMessage);
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<XFile?> _pickImage(ImageSource source) {
    return ImagePicker().pickImage(
      source: source,
      imageQuality: 100,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

  Future<void> _openMatch(CreatureScannerMatch match) async {
    final selectedEnemy = await _resolveEnemyForMatch(match);
    if (!mounted || selectedEnemy == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnemyDetailScreen(
          summary: selectedEnemy,
          variantSummaries: match.variants,
          initialGame: selectedEnemy.game,
        ),
      ),
    );
  }

  Future<EnemyIndexEntry?> _resolveEnemyForMatch(
    CreatureScannerMatch match,
  ) async {
    if (widget.selectedGameScope == scannerGameScopeG1 ||
        widget.selectedGameScope == scannerGameScopeG2) {
      return preferredScannerVariant(
        match.variants,
        selectedGameScope: widget.selectedGameScope,
      );
    }

    final variants = match.variants;
    if (variants.length == 1) {
      return variants.first;
    }

    final games = variants.map((enemy) => enemy.game).toSet();
    if (!games.contains('g1') || !games.contains('g2')) {
      return preferredScannerVariant(
        variants,
        selectedGameScope: scannerGameScopeAll,
      );
    }

    final preferenceKey = _variantPreferenceKey(match.creatureId);
    final storedPreferredGame = LocalStorage.getString(preferenceKey);
    if (storedPreferredGame != null) {
      return preferredScannerVariant(
        variants,
        selectedGameScope: scannerGameScopeAll,
        storedPreferredGame: storedPreferredGame,
      );
    }

    if (!mounted) {
      return null;
    }

    final game = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.scannerChooseGameTitle),
        content: Text(
          context.l10n.scannerChooseGameMessage(match.previewEnemy.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, scannerGameScopeG1),
            child: Text(context.l10n.groundedOne),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, scannerGameScopeG2),
            child: Text(context.l10n.groundedTwo),
          ),
        ],
      ),
    );

    if (game == null) {
      return null;
    }

    await LocalStorage.setString(preferenceKey, game);
    return preferredScannerVariant(
      variants,
      selectedGameScope: scannerGameScopeAll,
      storedPreferredGame: game,
    );
  }

  bool _isPermissionException(PlatformException error) {
    final code = error.code.toLowerCase();
    return code.contains('denied') ||
        code.contains('permission') ||
        code.contains('restricted');
  }

  String _errorMessageFor(
    CreatureScannerErrorType type,
    AppLocalizations l10n,
  ) {
    switch (type) {
      case CreatureScannerErrorType.timeout:
        return l10n.scannerTimeoutMessage;
      case CreatureScannerErrorType.invalidImage:
      case CreatureScannerErrorType.emptyResponse:
        return l10n.scannerNoMatchMessage;
      case CreatureScannerErrorType.payloadTooLarge:
        return l10n.scannerImageTooLargeMessage;
      case CreatureScannerErrorType.unknown:
        return l10n.scannerGenericErrorMessage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scannerTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 12),
              Icon(
                Icons.center_focus_strong,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.scannerTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(l10n.scannerNeedsInternet, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isAnalyzing
                    ? null
                    : () => _scan(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: Text(l10n.scannerTakePhotoAction),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isAnalyzing
                    ? null
                    : () => _scan(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: Text(l10n.scannerPickImageAction),
              ),
              const SizedBox(height: 20),
              if (_isAnalyzing)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(l10n.scannerAnalyzing),
                  ],
                ),
              if (_message != null) ...[
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_message!),
                        if (_lastRawLabels.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            l10n.scannerDetectedLabelsTitle,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(_lastRawLabels.join(', ')),
                        ],
                        if (_lastRawWebEntities.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            l10n.scannerDetectedWebTitle,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(_lastRawWebEntities.join(', ')),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _variantPreferenceKey(String speciesKey) =>
    'species_variant:$speciesKey';
