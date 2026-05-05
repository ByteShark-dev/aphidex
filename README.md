# Aphidex

Offline-first companion app for Grounded players. Aphidex bundles creature data,
weak points, effects, resistances, boss phases, and reference assets for
Grounded 1 and Grounded 2 in a single Flutter app.

## What It Includes

- Curated enemy data for both games
- Multilingual entries (`en`, `es`, `ru`)
- Weak point and damage-type analysis
- Boss phase breakdowns for major encounters
- Offline assets used directly by the mobile app

## Tech Stack

- Flutter
- Hive
- Google Mobile Ads
- Google Play Billing

## Repository Notes

- This repository contains the main app and its bundled data.
- Signing keys, local release config, and research PDFs are intentionally
  excluded from version control.
- Reference PDFs used during curation are kept outside shipped assets and are
  not part of the public repository.
- The repository is source-available, not open source. Private use and local
  modification are allowed, but redistribution, public forks, commercial use,
  and reuse of Aphidex branding are not allowed without written permission.

## License

- Code and repository contents: `Aphidex Source-Available License 1.0`
- Name, logo, and branding: see `TRADEMARKS.md`

## Development

```bash
flutter pub get
flutter test
flutter run
```

## Disclaimer

Aphidex is an unofficial fan-made project and is not affiliated with Obsidian
Entertainment or Xbox Game Studios.
