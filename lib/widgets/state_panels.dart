import 'package:flutter/material.dart';

import '../models/game_pick.dart';
import 'game_brand_mark.dart';

class AphidexStatePanel extends StatelessWidget {
  final GamePick gamePick;
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? body;
  final bool compact;

  const AphidexStatePanel({
    super.key,
    required this.gamePick,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.body,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveCompact = compact || MediaQuery.sizeOf(context).height < 520;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(effectiveCompact ? 14 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.94),
            colorScheme.surface.withValues(alpha: 0.98),
          ],
        ),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameBrandMark(gamePick: gamePick, height: effectiveCompact ? 20 : 30),
          SizedBox(height: effectiveCompact ? 12 : 22),
          Container(
            width: effectiveCompact ? 46 : 60,
            height: effectiveCompact ? 46 : 60,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              size: effectiveCompact ? 22 : 30,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(height: effectiveCompact ? 10 : 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: effectiveCompact ? 16 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: effectiveCompact ? 6 : 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (body != null) ...[
            SizedBox(height: effectiveCompact ? 12 : 16),
            body!,
          ],
          if (actions.isNotEmpty) ...[
            SizedBox(height: effectiveCompact ? 14 : 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class AphidexLoadingPanel extends StatelessWidget {
  final GamePick gamePick;
  final String title;
  final String subtitle;
  final bool compact;

  const AphidexLoadingPanel({
    super.key,
    required this.gamePick,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveCompact = compact || MediaQuery.sizeOf(context).height < 520;
    return AphidexStatePanel(
      gamePick: gamePick,
      icon: Icons.hourglass_top_rounded,
      title: title,
      subtitle: subtitle,
      compact: effectiveCompact,
      body: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: effectiveCompact ? 12 : 18),
          ...List.generate(
            effectiveCompact ? 1 : 3,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == (effectiveCompact ? 0 : 2) ? 0 : 10,
              ),
              child: Container(
                height: 12,
                width: index == 0 ? 220 : (index == 1 ? 180 : 140),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
