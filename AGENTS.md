# AGENTS.md - Aphidex

Proyecto Flutter/Dart de Aphidex, companion app no oficial de ByteShark para Grounded y Grounded 2.

## Reglas

- No modificar archivos sin revisar primero la estructura del proyecto, `pubspec.yaml`, `lib/main.dart` y el area afectada.
- No hacer commit, push, pull request ni deploy salvo autorizacion explicita.
- No inventar metricas comerciales, ratings, descargas, precios ni disponibilidad en tiendas.
- Antes de tocar la landing, revisar `landing/src/config/site.js`, SEO, enlaces de tiendas y responsive.
- Antes de tocar monetizacion, revisar `lib/controllers/monetization_controller.dart`, IDs de productos y AdMob.
- Antes de tocar el scanner, revisar `lib/config/feature_flags.dart`, `lib/scanner/` y `functions/`.
- No cambiar bundle id, `applicationId`, rutas de assets, estructura Firebase, Codemagic o GitHub Actions sin avisar primero.
- Mantener cambios minimos y compatibles con Flutter stable.

## Comandos Habituales

- App: `flutter pub get`, `flutter run`, `flutter test`, `flutter analyze lib test`.
- Scanner beta: `flutter run --dart-define=APHIDEX_SCANNER_ENABLED=true`.
- Android build: `flutter build appbundle --release`.
- iOS build: `flutter build ipa --release`.
- Landing: `cd landing && npm ci && npm run dev`.
- Landing build: `cd landing && npm run build`.
- Functions: `cd functions && npm ci && npm run build`.

## Validacion Esperada

- Para cambios Flutter: ejecutar `flutter analyze lib test` y `flutter test` si el entorno lo permite.
- Para landing: ejecutar `npm run build` dentro de `landing`.
- Para functions: ejecutar `npm run build` dentro de `functions`.
- Reportar claramente si no se pudo ejecutar algun comando.

## Riesgos Conocidos

- `cloudflare/` puede ser artefacto local no trackeado; no usarlo como fuente de verdad sin confirmar.
- `lib/firebase_options.dart` puede no existir localmente.
- La firma Android/iOS depende de secretos o archivos locales excluidos de Git.
