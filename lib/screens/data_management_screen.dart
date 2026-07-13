import 'package:flutter/material.dart';

import '../controllers/data_management_controller.dart';
import '../i18n/app_localizations.dart';
import '../i18n/data_management_strings.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = DataManagementStrings.forLanguage(context.l10n.languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(t['title'])),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(title: t['progress']),
            _ActionCard(
              icon: Icons.star_outline,
              title: t['favorites'],
              body: t['favoritesBody'],
              action: t['delete'],
              enabled: !_busy,
              onTap: () => _confirm(_DataAction.favorites, t),
            ),
            _ActionCard(
              icon: Icons.style_outlined,
              title: t['cards'],
              body: t['cardsBody'],
              action: t['reset'],
              enabled: !_busy,
              onTap: () => _confirm(_DataAction.cards, t),
            ),
            _ActionCard(
              icon: Icons.emoji_events_outlined,
              title: t['kills'],
              body: t['killsBody'],
              action: t['delete'],
              enabled: !_busy,
              onTap: () => _confirm(_DataAction.kills, t),
            ),
            _ActionCard(
              icon: Icons.person_outline,
              title: t['profile'],
              body: t['profileBody'],
              action: t['reset'],
              enabled: !_busy,
              onTap: () => _confirm(_DataAction.profile, t),
            ),
            const SizedBox(height: 12),
            _Section(title: t['preferences']),
            _ActionCard(
              icon: Icons.tune_outlined,
              title: t['filters'],
              body: t['filtersBody'],
              action: t['reset'],
              enabled: !_busy,
              onTap: () => _confirm(_DataAction.filters, t),
            ),
            _ActionCard(
              icon: Icons.school_outlined,
              title: t['tutorial'],
              body: t['tutorialBody'],
              action: t['reset'],
              enabled: !_busy,
              onTap: () => _confirm(_DataAction.tutorial, t),
            ),
            const SizedBox(height: 12),
            _Section(title: t['danger']),
            _ActionCard(
              icon: Icons.delete_forever_outlined,
              title: t['all'],
              body: t['allBody'],
              action: t['delete'],
              enabled: !_busy,
              danger: true,
              onTap: () => _confirm(_DataAction.all, t),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(_DataAction action, DataManagementStrings t) async {
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: !_busy,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            '${t['confirmPrefix']}${_title(action, t)}${t['confirmSuffix']}',
          ),
          content: Text(
            action == _DataAction.all ? t['allConfirmBody'] : t['confirmBody'],
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: Text(t['cancel']),
            ),
            FilledButton(
              onPressed: _busy ? null : () => Navigator.pop(context, true),
              child: Text(t['delete']),
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      switch (action) {
        case _DataAction.favorites:
          await DataManagementController.instance.clearFavorites();
        case _DataAction.cards:
          await DataManagementController.instance.clearCreatureCardProgress();
        case _DataAction.kills:
          await DataManagementController.instance.clearKillCounts();
        case _DataAction.profile:
          await DataManagementController.instance.clearPlayerProfile();
        case _DataAction.filters:
          await DataManagementController.instance.clearFiltersAndNavigation();
        case _DataAction.tutorial:
          await DataManagementController.instance.clearTutorialProgress();
        case _DataAction.all:
          await DataManagementController.instance.clearAllLocalData();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t['success'])));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t['error'])));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _title(_DataAction action, DataManagementStrings t) =>
      switch (action) {
        _DataAction.favorites => t['favorites'],
        _DataAction.cards => t['cards'],
        _DataAction.kills => t['kills'],
        _DataAction.profile => t['profile'],
        _DataAction.filters => t['filters'],
        _DataAction.tutorial => t['tutorial'],
        _DataAction.all => t['all'],
      };
}

enum _DataAction { favorites, cards, kills, profile, filters, tutorial, all }

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final bool enabled;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(body),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: enabled ? onTap : null, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
