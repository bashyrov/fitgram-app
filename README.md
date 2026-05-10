# Mealgram

AI calorie tracker tailored for the Polish market — photo scan, recipe input, quick database, plus an AI coach.

iOS-only, iOS 17+, SwiftUI + SwiftData + TCA, Supabase backend, Cloudflare Worker AI proxy.

## Quick start

```bash
make bootstrap      # one-time: install xcodegen, swiftlint, swift-format, xcbeautify
cp .env.example .env
make generate       # regenerate Xcode project from project.yml
make open           # open in Xcode
```

Common targets:

| command          | what it does                            |
|------------------|-----------------------------------------|
| `make build`     | xcodebuild for iPhone simulator         |
| `make test`      | unit + UI tests with coverage           |
| `make lint`      | SwiftLint strict                        |
| `make format`    | swift-format in-place                   |
| `make clean`     | wipe build artifacts                    |

## Project layout

```
Mealgram/
├── App/             # @main, root scene, app delegate adapter
├── Features/        # screens by feature (Auth, Today, Camera, Coach, …)
├── Core/            # Models, Services, Networking, Persistence, Utilities
├── DesignSystem/    # tokens (colors, type, spacing) + components
├── Resources/       # Assets.xcassets, Localizable.xcstrings, mocks
└── Supporting/      # Info.plist, PrivacyInfo.xcprivacy
```

## Required env vars

See `.env.example`. Bundle ID + Apple Team ID, Supabase URL/anon key, Google OAuth client ID, RevenueCat API key, Cloudflare Worker base URL.

## Phase status

Tracked in [ARCHITECTURE.md](./ARCHITECTURE.md). Current: **Phase 0 — Bootstrap**.

## License

Proprietary. © 2026 Mealgram.
