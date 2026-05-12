# Mealgram — Claude Context

## Project Overview
iOS-only AI calorie tracker for the Polish market. Three ways to log a meal: photo scan, recipe input, quick database. AI coach "Ola" with memory. Trial-then-paid via RevenueCat.

## Current Status
Phase 1 + most of Phase 2 merged. Done & merged on `develop`:
- M1.1 Auth (Apple real; Google/Email stubs; Keychain; TokenStore)
- M1.2 SwiftData schema v1 + PersistenceController
- M1.3 Networking (APIClient, retry, JWT interceptor)
- M1.4 Onboarding (7 steps + AppRouter)
- M1.5 Camera capture + mock detector + scan-result UI
- M1.6 code-complete: Cloudflare Worker (TypeScript) + iOS WorkerFoodDetector; awaiting Cloudflare/Gemini secrets to deploy
- M1.7 Today screen (streak header, calorie ring, macro bars, AI insight, meal timeline)
- M1.8 Profile (data export JSON, edit goals, preferences, privacy/terms, delete account)
- M1.9 Streaks (current/longest/freeze, registerLog on save, gap reset)
- M1.11 partial: SWIFT_EMIT_LOC_STRINGS enabled (full PL/EN/UK in M4.11)
- M1.12 Testing baseline
- M2.1 partial: CalibrationService + UI; factor auto-applied on photoScan save
- M2.2 partial: per-item edit + manual add in ScanResultView
- M2.3 partial: voice input (Polish SFSpeechRecognizer + confirm sheet); AI parsing TBD on Worker
- M2.4 Barcode scanner (AVCaptureMetadataOutput + Open Food Facts lookup)
- M2.6 Quick Database UI (search + category chips + portion sheet)
- M2.7 Polish food seed (43 dishes, idempotent FoodSeeder)
- M2.8 Achievements (engine + service + unlock banner + Profile grid)

- M2.10 partial: Weekly Progress tab (Swift Charts 7-day bar + breakdown)
- M3.4 partial: Recipe Library (CRUD + cook → MealEntry source=.recipe)
- M3.5 light: suggested-recipe card on Today with one-tap cook
- M4.7: Polish cultural-event banner (Wigilia/Tłusty Czwartek/Wielkanoc/…)
- Weight tracking: WeightEntry + trend chart in Profile

120 unit tests + 3 UI tests, swiftlint --strict clean, swift-format clean.

Four tabs: Dziś • Dodaj • Tydzień • Profil.
Five meal-entry paths from "+Dodaj": 📸 photo • 📦 barcode • 🔎 Szybka baza • 🎙 voice • 📖 recipe.

Blocked / awaiting from user:
- Supabase project URL + anon key (Email magic link + account-deletion server wipe)
- Google OAuth Client ID + URL scheme (Google Sign In SDK)
- Cloudflare Worker base URL + Gemini API key (Milestone 1.6 real food scan)
- Physical iPhone (Apple Sign In live, real camera capture, StoreKit sandbox)
- RevenueCat API key + product IDs (Milestone 1.10 paywall)
- Apple Team ID + App Store Connect (Milestone 1.13 fastlane / TestFlight)

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
