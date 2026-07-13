import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/game_selection_controller.dart';
import '../controllers/gold_controller.dart';
import '../controllers/player_display_name_controller.dart';
import '../controllers/player_profile_controller.dart';
import '../config/app_links.dart';
import '../data/enemy_repository.dart';
import '../data/player_character_catalog.dart';
import '../data/player_character_themes.dart';
import '../data/player_profile_stats.dart';
import '../i18n/app_localizations.dart';
import '../layout/app_breakpoints.dart';
import '../models/enemy_index_entry.dart';
import '../models/game_pick.dart';
import '../models/player_character.dart';
import '../models/player_character_theme.dart';
import '../services/player_profile_share_service.dart';
import '../widgets/game_brand_mark.dart';
import '../widgets/player_character_avatar.dart';

class PlayerProfileToolbarButton extends StatelessWidget {
  const PlayerProfileToolbarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('open-player-profile'),
      icon: const Icon(Icons.person_outline),
      tooltip: context.l10n.playerProfileTooltip,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlayerProfileScreen()),
      ),
    );
  }
}

class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({super.key});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final GlobalKey _shareBoundaryKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();
  Future<List<EnemyIndexEntry>>? _entriesFuture;
  AphidexGame? _entriesGame;
  String? _entriesLanguageCode;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    GameSelectionController.instance.gamePick.addListener(_refreshForGamePick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureEntriesFuture();
  }

  @override
  void dispose() {
    GameSelectionController.instance.gamePick.removeListener(
      _refreshForGamePick,
    );
    super.dispose();
  }

  void _refreshForGamePick() {
    if (mounted) {
      setState(_ensureEntriesFuture);
    }
  }

  void _ensureEntriesFuture() {
    final game = GameSelectionController.instance.profileGame;
    final languageCode = context.l10n.languageCode;
    if (_entriesFuture != null &&
        _entriesGame == game &&
        _entriesLanguageCode == languageCode) {
      return;
    }
    _entriesGame = game;
    _entriesLanguageCode = languageCode;
    _entriesFuture = EnemyRepository.loadGame(_storageGame(game), languageCode);
  }

  Future<void> _editDisplayName(BuildContext context) async {
    final isCompact = AppBreakpoints.surfaceForWidth(
      MediaQuery.sizeOf(context).width,
    ).isCompact;
    final editor = _DisplayNameEditor(
      initialValue: PlayerDisplayNameController.instance.displayName.value,
    );
    if (isCompact) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: editor,
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: editor,
        ),
      ),
    );
  }

  Future<void> _shareProfile(
    AphidexGame game,
    PlayerCharacter? character,
    PlayerProfileStats? stats,
  ) async {
    if (character == null || stats == null || _isExporting) {
      return;
    }
    try {
      await precacheImage(
        const AssetImage(PlayerProfileShareService.watermarkLogoAsset),
        context,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.playerProfileShareError)),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _isExporting = true);
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final bytes = await PlayerProfileShareService.capturePanel(
      _shareBoundaryKey,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isExporting = false);
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.playerProfileShareError)),
      );
      return;
    }
    final renderBox =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
    final wasShared = await PlayerProfileShareService.sharePng(
      bytes: bytes,
      fileName: PlayerProfileShareService.fileNameFor(game),
      text: context.l10n.playerProfileShareMessage(
        displayName: PlayerDisplayNameController.instance.displayName.value,
        game: _gameName(context.l10n, game),
        creatureCards: '${stats.cardsObtained}/${stats.cardsTotal}',
        goldCards: '${stats.goldCardsObtained}/${stats.goldCardsTotal}',
        website: AphidexLinks.publicWebsite,
      ),
      sharePositionOrigin: origin,
    );
    if (!wasShared && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.playerProfileShareError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureEntriesFuture();
    final profile = PlayerProfileController.instance;
    final displayName = PlayerDisplayNameController.instance;
    final gameSelection = GameSelectionController.instance;
    final gold = GoldController.instance;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.playerProfileTitle)),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            profile.selections,
            displayName.displayName,
            gameSelection.gamePick,
            gold.progress,
          ]),
          builder: (context, _) {
            final game = gameSelection.profileGame;
            final selected = profile.selectedCharacterFor(game);
            return LayoutBuilder(
              builder: (context, constraints) {
                final surface = AppBreakpoints.surfaceForWidth(
                  constraints.maxWidth,
                );
                return ListView(
                  padding: surface.pagePadding,
                  children: [
                    PlayerProfileGameSelector(activeGame: game),
                    const SizedBox(height: 16),
                    FutureBuilder<List<EnemyIndexEntry>>(
                      future: _entriesFuture,
                      builder: (context, snapshot) {
                        final stats = snapshot.hasData
                            ? summarizePlayerProfileStats(
                                snapshot.data!,
                                gold.progress.value,
                              )
                            : null;
                        return AnimatedSwitcher(
                          duration: MediaQuery.of(context).disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          child: PlayerProfileGamePanel(
                            key: ValueKey('player-profile-panel-${game.name}'),
                            repaintBoundaryKey: _shareBoundaryKey,
                            game: game,
                            character: selected,
                            stats: stats,
                            displayName: displayName.displayName.value,
                            isExporting: _isExporting,
                            shareButtonKey: _shareButtonKey,
                            onChangeCharacter: () =>
                                _openSelector(context, game),
                            onEditDisplayName: () => _editDisplayName(context),
                            onShare: () => _shareProfile(game, selected, stats),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class PlayerProfileGameSelector extends StatelessWidget {
  const PlayerProfileGameSelector({super.key, required this.activeGame});

  final AphidexGame activeGame;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedForeground = colorScheme.onSecondaryContainer;
    final unselectedForeground = colorScheme.onSurfaceVariant;
    final groundedForeground = activeGame == AphidexGame.grounded
        ? selectedForeground
        : unselectedForeground;
    final groundedTwoForeground = activeGame == AphidexGame.groundedTwo
        ? selectedForeground
        : unselectedForeground;
    return Semantics(
      label: l10n.playerProfileGameSelector,
      child: SegmentedButton<AphidexGame>(
        showSelectedIcon: false,
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? selectedForeground
                : unselectedForeground,
          ),
        ),
        segments: [
          ButtonSegment(
            value: AphidexGame.grounded,
            icon: SizedBox(
              height: 22,
              child: GameBrandMark(
                gamePick: GamePick.g1,
                height: 22,
                color: groundedForeground,
              ),
            ),
            label: Text(
              l10n.groundedOne,
              style: TextStyle(color: groundedForeground),
            ),
          ),
          ButtonSegment(
            value: AphidexGame.groundedTwo,
            icon: SizedBox(
              height: 22,
              child: GameBrandMark(
                gamePick: GamePick.g2,
                height: 22,
                color: groundedTwoForeground,
              ),
            ),
            label: Text(
              l10n.groundedTwo,
              style: TextStyle(color: groundedTwoForeground),
            ),
          ),
        ],
        selected: {activeGame},
        onSelectionChanged: (selection) {
          final game = selection.first;
          unawaited(
            GameSelectionController.instance.select(
              game == AphidexGame.grounded ? GamePick.g1 : GamePick.g2,
            ),
          );
        },
      ),
    );
  }
}

class PlayerProfileGamePanel extends StatelessWidget {
  const PlayerProfileGamePanel({
    super.key,
    required this.game,
    required this.character,
    required this.stats,
    required this.onChangeCharacter,
    this.repaintBoundaryKey,
    this.displayName = '',
    this.isExporting = false,
    this.shareButtonKey,
    this.onEditDisplayName,
    this.onShare,
  });

  final AphidexGame game;
  final PlayerCharacter? character;
  final PlayerProfileStats? stats;
  final VoidCallback onChangeCharacter;
  final GlobalKey? repaintBoundaryKey;
  final String displayName;
  final bool isExporting;
  final GlobalKey? shareButtonKey;
  final VoidCallback? onEditDisplayName;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = PlayerCharacterThemes.forCharacter(character);
    final isEmpty = character == null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVertical = constraints.maxWidth < 600;
        final panelHeight = isVertical ? 560.0 : 440.0;
        return RepaintBoundary(
          key: repaintBoundaryKey,
          child: Semantics(
            label: isEmpty
                ? context.l10n.playerProfileChooseAction
                : context.l10n.playerProfileSelected(
                    context.l10n.playerCharacterName(character!.id),
                  ),
            child: SizedBox(
              key: const ValueKey('player-profile-dynamic-panel'),
              height: panelHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PanelBackdrop(theme: theme),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GameIdentifier(
                            game: game,
                            foreground: theme.foreground,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: isVertical
                                ? _VerticalProfileContent(
                                    character: character,
                                    stats: stats,
                                    displayName: displayName,
                                    isExporting: isExporting,
                                    theme: theme,
                                    onChangeCharacter: onChangeCharacter,
                                    onEditDisplayName: onEditDisplayName,
                                    onShare: onShare,
                                    shareButtonKey: shareButtonKey,
                                  )
                                : _HorizontalProfileContent(
                                    character: character,
                                    stats: stats,
                                    displayName: displayName,
                                    isExporting: isExporting,
                                    theme: theme,
                                    onChangeCharacter: onChangeCharacter,
                                    onEditDisplayName: onEditDisplayName,
                                    onShare: onShare,
                                    shareButtonKey: shareButtonKey,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    if (!isExporting)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _ChangeCharacterButton(
                          isEmpty: isEmpty,
                          theme: theme,
                          onPressed: onChangeCharacter,
                        ),
                      ),
                    if (isExporting)
                      Positioned(
                        right: 16,
                        bottom: 14,
                        child: _ExportWatermark(foreground: theme.foreground),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VerticalProfileContent extends StatelessWidget {
  const _VerticalProfileContent({
    required this.character,
    required this.stats,
    required this.displayName,
    required this.isExporting,
    required this.theme,
    required this.onChangeCharacter,
    required this.onEditDisplayName,
    required this.onShare,
    required this.shareButtonKey,
  });

  final PlayerCharacter? character;
  final PlayerProfileStats? stats;
  final String displayName;
  final bool isExporting;
  final PlayerCharacterTheme theme;
  final VoidCallback onChangeCharacter;
  final VoidCallback? onEditDisplayName;
  final VoidCallback? onShare;
  final GlobalKey? shareButtonKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: _AvatarStage(
            character: character,
            theme: theme,
            isEmpty: character == null,
            onChangeCharacter: onChangeCharacter,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _ProfileIdentity(
            character: character,
            displayName: displayName,
            theme: theme,
            isExporting: isExporting,
            onEditDisplayName: onEditDisplayName,
          ),
        ),
        const SizedBox(height: 12),
        _StatsGrid(stats: stats, theme: theme),
        const SizedBox(height: 12),
        _ShareProfileButton(
          key: shareButtonKey,
          enabled: character != null,
          foreground: theme.foreground,
          isExporting: isExporting,
          onPressed: onShare,
        ),
      ],
    );
  }
}

class _HorizontalProfileContent extends StatelessWidget {
  const _HorizontalProfileContent({
    required this.character,
    required this.stats,
    required this.displayName,
    required this.isExporting,
    required this.theme,
    required this.onChangeCharacter,
    required this.onEditDisplayName,
    required this.onShare,
    required this.shareButtonKey,
  });

  final PlayerCharacter? character;
  final PlayerProfileStats? stats;
  final String displayName;
  final bool isExporting;
  final PlayerCharacterTheme theme;
  final VoidCallback onChangeCharacter;
  final VoidCallback? onEditDisplayName;
  final VoidCallback? onShare;
  final GlobalKey? shareButtonKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 210,
          child: _AvatarStage(
            character: character,
            theme: theme,
            isEmpty: character == null,
            onChangeCharacter: onChangeCharacter,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileIdentity(
                character: character,
                displayName: displayName,
                theme: theme,
                isExporting: isExporting,
                onEditDisplayName: onEditDisplayName,
                alignStart: true,
              ),
              const Spacer(),
              _StatsGrid(stats: stats, theme: theme),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: _ShareProfileButton(
                  key: shareButtonKey,
                  enabled: character != null,
                  foreground: theme.foreground,
                  isExporting: isExporting,
                  onPressed: onShare,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelBackdrop extends StatelessWidget {
  const _PanelBackdrop({required this.theme});

  final PlayerCharacterTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.backgroundStart, theme.backgroundEnd],
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-0.9, -0.9),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.accent.withValues(alpha: 0.16),
              ),
              child: const SizedBox(width: 160, height: 160),
            ),
          ),
          Align(
            alignment: const Alignment(1.05, 0.85),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.foreground.withValues(alpha: 0.08),
              ),
              child: const SizedBox(width: 240, height: 240),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameIdentifier extends StatelessWidget {
  const _GameIdentifier({required this.game, required this.foreground});

  final AphidexGame game;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final label = game == AphidexGame.grounded
        ? context.l10n.groundedOne
        : context.l10n.groundedTwo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ChangeCharacterButton extends StatelessWidget {
  const _ChangeCharacterButton({
    required this.isEmpty,
    required this.theme,
    required this.onPressed,
  });

  final bool isEmpty;
  final PlayerCharacterTheme theme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tooltip = isEmpty
        ? context.l10n.playerProfileSelectTooltip
        : context.l10n.playerProfileChangeTooltip;
    return Material(
      color: theme.backgroundStart.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: IconButton(
        key: const ValueKey('change-player-character'),
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          isEmpty ? Icons.person_add_alt_1 : Icons.edit_outlined,
          color: theme.foreground,
        ),
      ),
    );
  }
}

class _AvatarStage extends StatelessWidget {
  const _AvatarStage({
    required this.character,
    required this.theme,
    required this.isEmpty,
    required this.onChangeCharacter,
  });

  final PlayerCharacter? character;
  final PlayerCharacterTheme theme;
  final bool isEmpty;
  final VoidCallback onChangeCharacter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            math.min(constraints.maxWidth, constraints.maxHeight) *
            (isEmpty ? 0.68 : 0.82);
        return Center(
          child: Semantics(
            label: isEmpty
                ? context.l10n.playerProfileChooseAction
                : context.l10n.playerProfileSelected(
                    context.l10n.playerCharacterName(character!.id),
                  ),
            button: isEmpty,
            child: isEmpty
                ? TextButton(
                    onPressed: onChangeCharacter,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.foreground,
                      minimumSize: const Size(48, 48),
                    ),
                    child: PlayerCharacterAvatar(
                      character: null,
                      size: size,
                      theme: theme,
                      isEmpty: true,
                    ),
                  )
                : PlayerCharacterAvatar(
                    character: character,
                    size: size,
                    theme: theme,
                    mode: PlayerCharacterAvatarMode.main,
                  ),
          ),
        );
      },
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({
    required this.character,
    required this.displayName,
    required this.theme,
    required this.isExporting,
    required this.onEditDisplayName,
    this.alignStart = false,
  });

  final PlayerCharacter? character;
  final String displayName;
  final PlayerCharacterTheme theme;
  final bool isExporting;
  final VoidCallback? onEditDisplayName;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final foreground = theme.foreground;
    final name = displayName.isEmpty
        ? context.l10n.playerDisplayNameAdd
        : displayName;
    final characterName = character == null
        ? context.l10n.playerProfileChooseAction
        : context.l10n.playerCharacterName(character!.id);
    final nameStyle = TextStyle(
      color: foreground,
      fontSize: displayName.isEmpty ? 20 : 26,
      fontWeight: FontWeight.w900,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('player-display-name-group'),
          width: double.infinity,
          child: isExporting
              ? Text(
                  name,
                  key: const ValueKey('player-display-name-text'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: nameStyle,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      key: ValueKey('player-display-name-left-slot'),
                      width: 48,
                      height: 48,
                    ),
                    Expanded(
                      child: Text(
                        name,
                        key: const ValueKey('player-display-name-text'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: nameStyle,
                      ),
                    ),
                    SizedBox(
                      key: const ValueKey('player-display-name-edit-slot'),
                      width: 48,
                      child: IconButton(
                        key: const ValueKey('edit-player-display-name'),
                        tooltip: displayName.isEmpty
                            ? context.l10n.playerDisplayNameAdd
                            : context.l10n.playerDisplayNameEdit,
                        onPressed: onEditDisplayName,
                        color: foreground,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  ],
                ),
        ),
        Text(
          characterName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foreground.withValues(alpha: 0.78),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.theme});

  final PlayerProfileStats? stats;
  final PlayerCharacterTheme theme;

  @override
  Widget build(BuildContext context) {
    final cards = _ProfileStatTile(
      icon: Icons.style_outlined,
      label: context.l10n.playerProfileCreatureCards,
      value: stats == null
          ? null
          : '${stats!.cardsObtained}/${stats!.cardsTotal}',
      theme: theme,
    );
    final gold = _ProfileStatTile(
      icon: Icons.workspace_premium_outlined,
      label: context.l10n.playerProfileGoldCards,
      value: stats == null
          ? null
          : '${stats!.goldCardsObtained}/${stats!.goldCardsTotal}',
      theme: theme,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(children: [cards, const SizedBox(height: 8), gold]);
        }
        return Row(
          children: [
            Expanded(child: cards),
            const SizedBox(width: 10),
            Expanded(child: gold),
          ],
        );
      },
    );
  }
}

class _ProfileStatTile extends StatelessWidget {
  const _ProfileStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String? value;
  final PlayerCharacterTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: theme.foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.foreground.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.foreground.withValues(alpha: 0.86),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value ?? '—',
            style: TextStyle(
              color: theme.foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareProfileButton extends StatelessWidget {
  const _ShareProfileButton({
    super.key,
    required this.enabled,
    required this.foreground,
    required this.isExporting,
    required this.onPressed,
  });

  final bool enabled;
  final Color foreground;
  final bool isExporting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (isExporting) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: enabled
          ? context.l10n.playerProfileShareTooltip
          : context.l10n.playerProfileShareUnavailable,
      child: FilledButton.icon(
        key: const ValueKey('share-player-profile'),
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: foreground.withValues(alpha: 0.92),
          foregroundColor: Colors.black87,
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(Icons.share_outlined),
        label: Text(context.l10n.playerProfileShare),
      ),
    );
  }
}

class _ExportWatermark extends StatelessWidget {
  const _ExportWatermark({required this.foreground});

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('player-profile-export-watermark'),
      padding: const EdgeInsets.only(right: 8, bottom: 6),
      child: Opacity(
        opacity: 0.84,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              PlayerProfileShareService.watermarkLogoAsset,
              key: const ValueKey('player-profile-export-watermark-logo'),
              width: 20,
              height: 20,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 6),
            Text(
              'Aphidex',
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplayNameEditor extends StatefulWidget {
  const _DisplayNameEditor({required this.initialValue});

  final String initialValue;

  @override
  State<_DisplayNameEditor> createState() => _DisplayNameEditorState();
}

class _DisplayNameEditorState extends State<_DisplayNameEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String value) async {
    await PlayerDisplayNameController.instance.save(value);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.playerDisplayNameTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('player-display-name-field'),
            controller: _controller,
            autofocus: true,
            maxLength: PlayerDisplayNameController.maxLength,
            textInputAction: TextInputAction.done,
            onSubmitted: _save,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => Text(
                  l10n.playerDisplayNameCounter.replaceFirst(
                    '{current}',
                    '$currentLength',
                  ),
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancelAction),
              ),
              if (widget.initialValue.isNotEmpty)
                TextButton(
                  onPressed: () => _save(''),
                  child: Text(l10n.playerDisplayNameRemove),
                ),
              FilledButton(
                onPressed: () => _save(_controller.text),
                child: Text(l10n.playerDisplayNameSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _openSelector(BuildContext context, AphidexGame game) async {
  final isCompact = AppBreakpoints.surfaceForWidth(
    MediaQuery.sizeOf(context).width,
  ).isCompact;
  if (isCompact) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.78,
        child: PlayerProfileCharacterSelector(game: game),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
        child: PlayerProfileCharacterSelector(game: game),
      ),
    ),
  );
}

class PlayerProfileCharacterSelector extends StatelessWidget {
  const PlayerProfileCharacterSelector({super.key, required this.game});

  final AphidexGame game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = PlayerProfileController.instance;
    final characters = PlayerCharacterCatalog.forGame(game);
    final selectedId = profile.selectedIdFor(game);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.playerProfileSelectorTitle(_gameName(l10n, game)),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.playerProfileSelectorSubtitle,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: characters.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final character = characters[index];
                  final theme = PlayerCharacterThemes.forCharacter(character);
                  final isSelected = character.id == selectedId;
                  return ListTile(
                    key: ValueKey('player-profile-option-${character.id}'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: theme.backgroundStart,
                    leading: PlayerCharacterAvatar(
                      character: character,
                      size: 48,
                      theme: theme,
                      isSelected: isSelected,
                      mode: PlayerCharacterAvatarMode.compact,
                    ),
                    title: Text(
                      l10n.playerCharacterName(character.id),
                      style: TextStyle(
                        color: theme.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: Icon(
                      isSelected ? Icons.check_circle : Icons.chevron_right,
                      color: isSelected ? theme.accent : theme.foreground,
                    ),
                    onTap: () async {
                      await profile.select(game, character.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
            if (selectedId != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                key: ValueKey('clear-player-profile-${game.name}'),
                onPressed: () async {
                  await profile.clear(game);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.person_off_outlined),
                label: Text(l10n.playerProfileClearAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _gameName(AppLocalizations l10n, AphidexGame game) => switch (game) {
  AphidexGame.grounded => l10n.groundedOne,
  AphidexGame.groundedTwo => l10n.groundedTwo,
};

String _storageGame(AphidexGame game) => switch (game) {
  AphidexGame.grounded => 'g1',
  AphidexGame.groundedTwo => 'g2',
};
