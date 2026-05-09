# Aphidex iOS Publish Checklist

Current repo status:

- iOS bundle identifier aligned to `com.byteshark.aphidex`
- App Store Connect Apple ID: `6766727089`
- App Store Connect SKU: `aphidex-ios`
- Primary language: `Español (México)`
- iOS minimum deployment target is `15.5`
- No camera or photo-library permission strings are shipped yet
- App-level privacy manifest added
- Review prompt is enabled on iOS and opens the App Store page for Apple ID `6766727089`
- iOS AdMob app ID is configured in `Info.plist`
- iOS remove-ads purchase is wired to `com.byteshark.aphidex.no_ads`
- Scanner is not active for the first iOS release
- The first Codemagic iOS build failed because the deployment target was too low for `google_mlkit_commons`
- That issue was corrected by raising the project minimum to iOS `15.5`
- A signed `Aphidex.ipa` has already been generated successfully in Codemagic
- Build 6 generated a signed IPA correctly, but it only published internal artifacts and did not upload to TestFlight
- The Codemagic YAML has now been corrected for real App Store Connect / TestFlight upload
- A later TestFlight build showed a white screen and immediate crash on launch
- The startup path was hardened in Dart, and iOS `Info.plist` now includes the real AdMob app ID because the Google Mobile Ads SDK can crash iOS at launch if `GADApplicationIdentifier` is missing

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
11. Confirm that `APP_STORE_APPLE_ID=6766727089` stays aligned in Codemagic if you duplicate or fork the workflow.
12. Run `ios-release-build` again and verify the uploaded build in App Store Connect > TestFlight.

### Codemagic secrets and signing TODOs

Do not commit these to the repository. Configure them in Codemagic UI only:

- `APPLE_DEVELOPER_TEAM_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `CERTIFICATE_PRIVATE_KEY`
- `APP_STORE_APPLE_ID` = `6766727089`
- Bundle ID confirmation: `com.byteshark.aphidex`

Notes:

- The current workflow is prepared to attempt an unsigned iOS archive when signing is not configured yet.
- A proper distributable `.ipa` normally requires working iOS code signing.
- The first goal is to validate that the iOS project builds in Codemagic macOS.
- The workflow now imports the Codemagic variable group `ios_signing_credentials`.
- With the current automatic-signing approach, `CERTIFICATE_PRIVATE_KEY` is still required.
- The workflow now uses a direct `publishing.app_store_connect` block with `submit_to_testflight: true`.
- That change was made because build 6 only showed artifact publishing and did not perform a real TestFlight upload.
- This workflow is now intended to behave as a real `testflight-release` flow, not just as an IPA artifact generator.
- The bundled Google Mobile Ads SDK expects `GADApplicationIdentifier` in `Info.plist`, even before every ad surface is fully tuned.
- Aphidex now uses the real iOS AdMob app ID in `Info.plist`.

How to generate `CERTIFICATE_PRIVATE_KEY` for Codemagic automatic signing:

1. On a Mac, generate a new RSA 2048 private key:
   `ssh-keygen -t rsa -b 2048 -m PEM -f ~/Desktop/ios_distribution_private_key -q -N ""`
2. Or, if you already have the matching iOS Distribution certificate on a Mac:
   export it from Keychain Access as `.p12`.
3. Then extract the private key from that `.p12`:
   `openssl pkcs12 -in IOS_DISTRIBUTION.p12 -nodes -nocerts | openssl rsa -out ios_distribution_private_key`
4. Save the resulting PEM text as the Codemagic secret `CERTIFICATE_PRIVATE_KEY`.

App Store Connect tasks:

1. Add app name, subtitle, privacy policy URL, support URL, and age rating.
2. Upload iPhone screenshots and iPad screenshots if you keep iPad enabled.
3. Complete the App Privacy questionnaire.
4. Decide whether iOS launch will be ad-free or whether AdMob will be enabled later.
5. Copy the numeric Apple ID from App Store Connect > App Information into `APP_STORE_APPLE_ID`.
6. Trigger `ios-release-build` and verify the build appears in App Store Connect > TestFlight after Codemagic post-processing finishes.

App metadata currently registered:

- App name: `Aphidex`
- Bundle ID: `com.byteshark.aphidex`
- SKU: `aphidex-ios`
- Apple ID: `6766727089`
- Primary language: `Español (México)`

iOS monetization status:

- Ads can initialize on iOS with the configured AdMob app ID.
- The remove-ads flow now queries the iOS product `com.byteshark.aphidex.no_ads`.
- `Restore purchases` is available in the shared settings flow for iOS and Android.

Current Apple requirements to keep in mind:

- App uploads must use a current supported Xcode/SDK combination.
- App Store submissions require valid privacy manifests for the app and certain third-party SDKs.
- If App Store Connect reports a missing or invalid privacy manifest from a dependency, update that SDK before submitting again.
- Aphidex iOS now requires iOS `15.5+` because `google_mlkit_commons` / ML Kit requires that minimum.

Nice-to-have before release:

1. Optionally replace the external App Store review flow with Apple's in-app review sheet later.
2. Test camera scan, gallery scan, credits flow, and external links on a real iPhone.
3. Decide whether to keep iPad support or restrict the target to iPhone only.

## Fase posterior: AdMob iOS + In-App Purchase

Pendientes para una version futura:

1. Crear la app iOS en AdMob.
2. Agregar `SKAdNetworkItems` completos segun la documentacion vigente de AdMob.
3. Terminar la validacion real del IAP `com.byteshark.aphidex.no_ads` en sandbox/TestFlight.
4. Confirmar visualmente que `restore purchases` funciona en iOS.
5. Actualizar App Privacy en App Store Connect segun el stack final de monetizacion.
