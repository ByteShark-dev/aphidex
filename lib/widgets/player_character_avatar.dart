import 'package:flutter/material.dart';

import '../data/player_character_themes.dart';
import '../models/player_character.dart';
import '../models/player_character_theme.dart';

enum PlayerCharacterAvatarMode { compact, main }

class PlayerCharacterAvatar extends StatelessWidget {
  const PlayerCharacterAvatar({
    super.key,
    required this.character,
    required this.size,
    required this.theme,
    this.scale,
    this.alignment,
    this.isSelected = false,
    this.isEmpty = false,
    this.mode = PlayerCharacterAvatarMode.main,
  });

  final PlayerCharacter? character;
  final double size;
  final PlayerCharacterTheme theme;
  final double? scale;
  final Alignment? alignment;
  final bool isSelected;
  final bool isEmpty;
  final PlayerCharacterAvatarMode mode;

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = isEmpty ? PlayerCharacterThemes.empty : theme;
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final outerBorderWidth = mode == PlayerCharacterAvatarMode.compact
        ? 2.0
        : 3.0;
    final ringGap = mode == PlayerCharacterAvatarMode.compact ? 2.0 : 3.0;
    final innerBorderWidth = mode == PlayerCharacterAvatarMode.compact
        ? 1.0
        : 1.5;

    return SizedBox.square(
      key: const ValueKey('player-character-avatar'),
      dimension: size,
      child: DecoratedBox(
        key: const ValueKey('player-character-avatar-outer-ring'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              effectiveTheme.backgroundStart,
              effectiveTheme.backgroundEnd,
            ],
          ),
          border: Border.all(
            color: isSelected
                ? effectiveTheme.accent
                : effectiveTheme.accent.withValues(alpha: 0.78),
            width: outerBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: effectiveTheme.backgroundStart.withValues(alpha: 0.32),
              blurRadius: mode == PlayerCharacterAvatarMode.compact ? 5 : 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(ringGap),
          child: DecoratedBox(
            key: const ValueKey('player-character-avatar-inner-ring'),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: effectiveTheme.backgroundStart.withValues(alpha: 0.42),
              border: Border.all(
                color: effectiveTheme.foreground.withValues(alpha: 0.28),
                width: innerBorderWidth,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(innerBorderWidth + 1),
              child: ClipOval(
                key: const ValueKey('player-character-avatar-clip'),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: character?.avatar.padding ?? EdgeInsets.zero,
                  child: isEmpty || character == null
                      ? Center(
                          child: Text(
                            '+',
                            style: TextStyle(
                              color: effectiveTheme.foreground,
                              fontSize:
                                  mode == PlayerCharacterAvatarMode.compact
                                  ? size * 0.52
                                  : size * 0.58,
                              height: 0.9,
                              fontWeight: FontWeight.w200,
                            ),
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: duration,
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.96,
                                    end: 1,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Transform.scale(
                            key: ValueKey(character!.id),
                            scale: scale ?? character!.avatar.scale,
                            child: Image.asset(
                              character!.assetPath,
                              fit: character!.avatar.fit,
                              alignment:
                                  alignment ?? character!.avatar.alignment,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(
                                  Icons.person_outline,
                                  color: effectiveTheme.foreground,
                                  size: size * 0.42,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
