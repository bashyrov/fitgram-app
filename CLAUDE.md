# Mealgram — Claude Context

## Project Overview
iOS-only AI calorie tracker for the Polish market. Three ways to log a meal: photo scan, recipe input, quick database. AI coach "Ola" with memory. Trial-then-paid via RevenueCat.

## Current Status
Phase 1 mid-sprint. Done & merged on `develop`:
- M1.1 Auth (Apple Sign In real, Google/Email stubs, Keychain, TokenStore)
- M1.2 SwiftData schema v1 + PersistenceController
- M1.3 Networking (APIClient, retry, JWT interceptor)
- M1.4 Onboarding (7 steps + AppRouter)
- M1.5 Camera capture + mock detector + scan-result UI

32 unit tests green, swiftlint --strict clean, swift-format clean.

Blocked / awaiting from user:
- Supabase project URL + anon key (needed by Email magic link + Account Deletion server-side wipe)
- Google OAuth Client ID (needed by Google Sign In)
- Cloudflare Worker base URL + Gemini API key (for Milestone 1.6 real food scan)
- Physical iPhone (for AppleSignIn live, real camera capture, StoreKit sandbox)
- RevenueCat API key + product setup (Milestone 1.10 paywall)

## Tech Stack (always reference)
- Swift 5.10, strict concurrency, SwiftUI iOS 17+, SwiftData, TCA for complex flows
- Supabase (Postgres + Auth + Storage + Edge Fn + pgvector)
- Cloudflare Workers (AI proxy) + Upstash Redis cache
- Gemini 2.5 Flash (default vision), Pro (premium), Claude Sonnet 4.5 (Coach)
- RevenueCat for subs, Sentry + PostHog
- xcodegen, swiftlint, swift-format, xcbeautify

## Important Conventions
- All strings via `String(localized:)` (default lang: pl)
- All colors via Asset Catalog (`Color("BrandPrimary")` or `Tokens.Color.primary`)
- All sizing via `Tokens.Space.*`, all radii via `Tokens.Radius.*`
- No force unwraps in app code (`force_unwrapping: error` in swiftlint)
- No `print()` — use `Logger` (`os.log`)
- async/await everywhere; `@MainActor` on UI; actor isolation on shared state
- SF Pro Rounded for all UI text
- Design must feel light, calm, generous whitespace (per product brief 2026-05-10)

## Files Critical to Read
- `ARCHITECTURE.md` — all architectural decisions + decision log
- `README.md` — setup
- `project.yml` — Xcode project config (regenerate via `make generate`)
- `.env.example` — required env vars
- `.swiftlint.yml`, `.swift-format` — code quality config

## Commands
- `make build` — build for simulator
- `make test` — run tests + coverage
- `make lint` — swiftlint --strict
- `make format` — swift-format in-place
- `make generate` — regenerate Xcode project after `project.yml` changes
- `make open` — generate + open Xcode

## Things to NEVER Do
- Never commit `.env`
- Never push directly to `main`
- Never force push
- Never bypass auth in code paths
- Never hardcode API keys in app (always proxied via Cloudflare Worker)
- Never disable swiftlint rules without recording in ARCHITECTURE.md

## Workflow
- Branch from `develop` (`feature/*`), commit early/often per Conventional Commits.
- After each Milestone: commit, brief status update, move to next.
- Stop only for the events listed in `mealgram-master-prompt.md` (Bundle ID, credentials, physical-device tests, App Store assets, true architectural pivot).

## Last Session Summary
2026-05-10 — Phase 0 bootstrap complete. Project structure scaffolded, configs written (gitignore, project.yml, swiftlint, swift-format, Makefile), README + ARCHITECTURE + CLAUDE.md drafted. Design system tokens in progress. Next: generate Xcode project, verify it builds clean, initial commit, then ask user for Bundle ID + Team ID.
