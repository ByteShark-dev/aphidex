# Aphidex iOS Publish Checklist

Current repo status:

- iOS bundle identifier aligned to `com.byteshark.aphidex`
- No camera or photo-library permission strings are shipped yet
- App-level privacy manifest added
- Review prompt disabled on iOS until a real App Store ID is assigned
- Ads and remove-ads purchase remain Android-only in app code
- Scanner is not active for the first iOS release

What still needs to happen on a Mac:

1. Open `ios/Runner.xcworkspace` or `ios/Runner.xcodeproj` in Xcode 16 or later.
2. Sign in with the Apple Developer account in Xcode.
3. Set the `Runner` team and verify automatic signing.
4. Confirm the app record exists in App Store Connect for bundle ID `com.byteshark.aphidex`.
5. Archive a build and validate it locally in Xcode.
6. Upload the build to App Store Connect or TestFlight.

## Codemagic setup

1. Create a Codemagic account.
2. Connect your GitHub account to Codemagic.
3. Add the `ByteShark-dev/Aphidex` repository in Codemagic.
4. Make sure Codemagic detects the root `codemagic.yaml`.
5. Open the workflow `ios-release-build`.
6. Configure App Store Connect API credentials in Codemagic UI.
7. Configure iOS code signing in Codemagic.
8. Run the workflow `ios-release-build`.
9. Review build logs, especially `xcodebuild` logs if present.
10. Download the `.ipa` artifact if one is generated.
11. Only after that, enable publishing to TestFlight.

### Codemagic secrets and signing TODOs

Do not commit these to the repository. Configure them in Codemagic UI only:

- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `CERTIFICATE_PRIVATE_KEY`
- Apple Developer Team ID
- Bundle ID confirmation: `com.byteshark.aphidex`

Notes:

- The current workflow is prepared to attempt an unsigned iOS archive when signing is not configured yet.
- A proper distributable `.ipa` normally requires working iOS code signing.
- The first goal is to validate that the iOS project builds in Codemagic macOS.

App Store Connect tasks:

1. Add app name, subtitle, privacy policy URL, support URL, and age rating.
2. Upload iPhone screenshots and iPad screenshots if you keep iPad enabled.
3. Complete the App Privacy questionnaire.
4. Decide whether iOS launch will be ad-free or whether AdMob will be enabled later.

iOS monetization status:

- The current code does not initialize ads or in-app purchases on iOS.
- That means an initial iOS release can ship without ads and without the `remove ads` purchase flow.

Current Apple requirements to keep in mind:

- App uploads must use a current supported Xcode/SDK combination.
- App Store submissions require valid privacy manifests for the app and certain third-party SDKs.
- If App Store Connect reports a missing or invalid privacy manifest from a dependency, update that SDK before submitting again.

Nice-to-have before release:

1. Add the real iOS App Store ID to `ReviewPromptController` once the app exists.
2. Test camera scan, gallery scan, credits flow, and external links on a real iPhone.
3. Decide whether to keep iPad support or restrict the target to iPhone only.

## Fase posterior: AdMob iOS + In-App Purchase

Pendientes para una version futura:

1. Crear la app iOS en AdMob.
2. Agregar el `GADApplicationIdentifier` real a `ios/Runner/Info.plist`.
3. Agregar `SKAdNetworkItems` completos segun la documentacion vigente de AdMob.
4. Crear el IAP `com.byteshark.aphidex.no_ads`.
5. Implementar y probar `restore purchases` en iOS.
6. Actualizar App Privacy en App Store Connect segun el stack final de monetizacion.
7. Activar el App Store ID real en `ReviewPromptController` para el review prompt de iOS.
