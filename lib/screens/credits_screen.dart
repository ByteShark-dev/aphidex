import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/app_localizations.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const _wikiUrl = 'https://grounded.fandom.com';
  static const _wikiGgCardsUrl =
      'https://grounded.wiki.gg/wiki/Creature_Cards_(Grounded_2)';
  static const _licenseUrl = 'https://creativecommons.org/licenses/by-sa/4.0/';

  static const List<String> donors = ['- Your name here -', 'Smolyuu'];

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsTitle)),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.appTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.creditsAppTagline,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.creditsContentTitle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(l10n.creditsContentBody),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.groundedWikiButton),
                  onPressed: () => _open(_wikiUrl),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.groundedTwoWikiButton),
                  onPressed: () => _open(_wikiGgCardsUrl),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.ccLicenseButton),
                  onPressed: () => _open(_licenseUrl),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              l10n.donorsTitle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (donors.isEmpty)
              Text(l10n.noDonorsYet, style: const TextStyle(color: Colors.grey))
            else
              ...donors.map(
                (name) => ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.red),
                  title: Text(name),
                ),
              ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                l10n.footerText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
