# Fitgram Deploy Readiness

Last checked: 2026-08-11

## Ready in code

- App display name is `Fitgram` in generated project settings and app/watch/widget plist values.
- Release build number is `7` in `project.yml`, app plist, watch plist, and widget plist.
- Alternate app icons are explicitly included through `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` and verified inside the Release archive `Assets.car`.
- Paywall uses StoreKit 2 products:
  - `fitgram_premium_monthly`
  - `fitgram_premium_yearly`
- StoreKit fallback no longer unlocks Premium locally when App Store products are unavailable.
- Paywall includes direct Terms and Privacy links:
  - https://fitgram.space/terms
  - https://fitgram.space/privacy
- Account deletion deletes server data first when Supabase is configured, then local SwiftData, files, notifications, widget data, defaults, Spotlight, and auth tokens.
- Account deletion warning tells users that Apple subscriptions must be cancelled separately and provides an Apple subscription-management action.
- Empty voice input does not proceed to gram adjustment unless recognizable food text exists.
- Release photo AI does not fall back to mock when `WORKER_BASE_URL` is absent; it returns an unconfigured detector instead.
- Widget device builds no longer compile preview macros.

## Verified locally

- `make generate` passed.
- `make format` passed.
- Generic iOS build passed:
  - `xcodebuild -scheme Fitgram -destination 'generic/platform=iOS' ... build`
- iPhone 17 Pro simulator test run exited successfully:
  - `xcodebuild -scheme Fitgram -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' ... test`
- Targeted lint for changed release files found 0 code violations.
- `fastlane ios prepare_metadata` finished successfully and staged metadata + screenshots in App Store Connect.
- `fastlane ios beta` built, signed, exported, processed, and uploaded build `7` artifacts:
  - IPA: `build/Fitgram.ipa`
  - dSYM: `build/Fitgram.app.dSYM.zip`
- Build `7` finished App Store Connect processing and had its changelog set successfully.
- The beta lane uses `skip_waiting_for_build_processing: true`, but fastlane may still briefly wait to set the changelog when one is supplied.

## Known non-blocking warnings

- Full lint still reports older style/size violations in large feature files.
- Xcode prints many Swift 6 future-warning messages from SwiftData predicates, AppIntents static properties, and Sendable annotations. Current build succeeds, but this should be cleaned before moving the project fully to Swift 6 mode.
- `swiftlint` returns a cache-file error in this environment even when selected files have 0 violations.
- Fastlane reported already-uploaded screenshots for most locales and skipped extra `uk` iPad 12.9 screenshots because App Store Connect already has the maximum for that device class.

## App Store Connect checklist

- App Information:
  - Privacy Policy URL: `https://fitgram.space/privacy`
  - Support URL: `https://fitgram.space/support`
- Metadata:
  - Every localization description includes `https://fitgram.space/terms`.
  - Review notes include Terms and Privacy links.
- Subscriptions:
  - Products exist exactly as `fitgram_premium_monthly` and `fitgram_premium_yearly`.
  - Each product has price, localized display name/description, and review screenshot.
  - If using trial, each product has a 7-day free trial in App Store Connect.
  - Subscription group is attached to the app version being submitted.
- Account deletion:
  - Confirm reviewer can reach Profile -> Settings -> Account -> Delete account.
  - If a test subscription is active, confirm the app tells the user to cancel it in Apple ID.

## External release dependencies

- App Store Connect API key in `.env.fastlane` for metadata/upload lanes.
- Valid Apple distribution signing for app and widget targets.
- Live Cloudflare Worker with Gemini secret configured.
- Supabase URL and anon key must remain valid for social/profile/delete-account server paths.
- Google OAuth client must match bundle id and URL scheme in project settings.

## Useful commands

```bash
make generate
make format

xcodebuild -scheme Fitgram \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild -scheme Fitgram \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' \
  -derivedDataPath build/DerivedData \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  test

bundle exec fastlane ios prepare_metadata
bundle exec fastlane ios beta
```

## Apple references checked

- App Review Guidelines, subscriptions and metadata: https://developer.apple.com/app-store/review/guidelines/
- App information fields: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- In-app purchase information: https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/
- Account deletion requirements: https://developer.apple.com/support/offering-account-deletion-in-your-app/
