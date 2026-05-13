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
- Apple Health: read-only body-mass import (entitlement activates with Team ID)
- M4.1 + M4.2 partial: Friends scaffold — domain types, @MainActor
  FriendService protocol, InMemoryFriendService (seeded Kasia/Michał/Ola
  + pending Nina), FriendsState, full UI (incoming card, feed,
  reactions, search + QR placeholder, unfriend), 5th "Znajomi" tab.
  Real backend swaps in via composition root when Supabase URL+anon key
  arrive.
- M2.9 Local notifications: NotificationService + pure-function
  NotificationPlanner + UserDefaults-backed PreferencesStore +
  NotificationCoordinator (reschedules at launch + on every meal save
  via ChainedMealSaver). Three channels — morning 08:00, streak risk
  20:30, evening summary 21:00. Profile toggle for each.
- M3.1 partial: AI Coach "Ola" — rule-based generator with 8
  prioritised rules (streak milestone, weight progress, streak-at-risk,
  protein gap, calorie overshoot, light-evening, balanced week,
  first-meal reminder). CoachService bundles SwiftData reads into a
  CoachContext snapshot. AIInsightCard renders headline insight with
  optional CTA chip wired through to scanner/quickDB/recipes/weight
  tab. Claude-backed generator slots in behind same protocol.
- M3.1 expansion: Weekly Debrief sheet "Co u Ciebie" — stats grid
  (avg kcal / calorie days hit / protein days hit / days logged /
  current streak) + full insight list. Headline ladder Cudowny →
  Solidny → Mieszany → łapać rytm based on calorie days in window.
  Entry shortcut card on Today between insight + meals.
- Meal edit/delete: MealRepository (delete + updatePortion via cross-
  context id-refetch). MealDetailSheet raised by tapping any timeline
  row. Portion slider + destructive confirm. Refresh fans out to
  TodayState + ProgressState via existing pipeline.
- M2.10 expansion: 30-day calorie chart on Tydzień tab — bars per day
  + 7-day moving average line + goal RuleMark. ProgressState now
  reads 30 days in a single query and reuses the slice for the 7-day
  bucket.
- Profile activity heatmap: 90-day GitHub-style contribution grid
  driven by daily calorie totals (4 intensity tiers). Mon-first
  weekday rows, sage palette.
- M4.3 partial: Weekly Challenges — 6 catalog challenges (logged days,
  protein days, calorie band, breakfast days, distinct foods, recipe
  cooks). Auto-rolling per ISO week (Mon start). Pure ChallengeEvaluator
  + ChallengeService glue. Profile entry "Wyzwania tygodnia (N
  ukończone)" raises sheet with per-challenge progress bars.
- M2.9 Local notifications: NotificationService over UNUserNotification-
  Center + pure NotificationPlanner + UserDefaults-backed Preferences-
  Store + Coordinator (reschedules at launch + after every meal save
  via ChainedMealSaver). Three channels (morning/streak-risk/evening),
  morning + streak-risk silenced once user logs today.
- Achievements grown 8 → 14: recipe.first / voice.first / quickdb.first
  / weight.tracked / macros.balanced (±10 % on all 3 goals one day) /
  week.consistent (7 days in a row, beats streak.* for early users).
  Engine Inputs struct carries macro goals + weight flag.
- Friends Leaderboard: trophy button on Znajomi raises a ranked sheet
  with medal top-3 + user's row highlighted regardless of rank.
  Standard Competition Ranking; ties share rank; name-asc tiebreaker.
- Quick DB recents: Food model gained pickCount + lastPickedAt. Two
  horizontal carousels ("Ostatnie" + "Częste") above the all-foods
  list when no query/category active. recordPick fires alongside save.
- Streak freeze UI: warm snowflake card on Today appears when
  currentLength > 0, freezesAvailable > 0, nothing logged today.
  One tap consumes a freeze via StreakService and refreshes.
- Coach insight history: new @Model CoachInsightLog (added to
  MealgramSchemaV1.models). CoachInsightLogStore idempotent on
  (user, weekStart) — same-week debriefs update existing row.
  WeeklyDebriefView clock toolbar raises CoachHistoryView with
  expandable per-week cards.
- Meal undo banner: MealEntrySnapshot value type captures meal +
  items before delete. Five-second snackbar at bottom of MainTabView
  with "Cofnij" pill; restoration rebuilds fresh @Model and goes
  through normal MealSaving pipeline.
- Polish food seed grew 43 → 78 entries: Placki, Pierogi z mięsem,
  Barszcz, Sernik, Szarlotka, Skyr, Migdały, Awokado + many more.
  Seeder test now asserts ≥ 60 entries + every category populated +
  no duplicate IDs.
- Recipe sort menu: .recent / .nameAsc / .cookedCount (count desc +
  name asc tiebreak). Toolbar Menu picker bound to state.sort.
- Recipe nutrition estimator: pure-function service matches ingredient
  lines against the Food catalog (exact name → shared-token fallback,
  ≥ 4-char tokens). Estimate value carries per-serving macros + matched
  count + unmatched names. "Oszacuj" chip in RecipeFormSheet populates
  the form draft.
- Profile lifetime stats card: 2x2 grid of total meals/recipes/weight
  entries/achievements + "Z nami od …" month-year footer.
- Coach feedback thumbs: optional Bool? on CoachInsightLog (lightweight
  migration). "Pomocne?" row on WeeklyDebriefView collapses to a
  thank-you after thumbs-up or thumbs-down.
- Meal photo persistence: MealPhotoStore writes JPEG to
  Documents/MealPhotos/ under fresh UUID filenames. ScanState.commit
  persists imageData → sets MealEntry.photoFilename. MealDetailSheet
  shows a 200pt photo header when filename resolves.
- Streak share card: 1080×1920 portrait card rendered via ImageRenderer,
  ShareLink hands the PNG to UIActivityViewController. "Udostępnij
  serię" row in Profile (visible only when streak.currentLength > 0).
- Voice meal parser: pure-function PL regex parser extracts grams +
  kcal from common phrasings ("schabowy 200 gram 400 kcal"), matches
  residual name against Food catalog for real per-100g macros. Wired
  into VoiceFlowState.commit. No LLM needed.
- Coach insight dismissal: long-press the insight card →
  "Ukryj na dziś" → CoachDismissalStore (UserDefaults, day-scoped)
  filters that headline out of insights(for:) until midnight rollover.
- MealCSV export: Excel-friendly CSV (Polish headers, RFC 4180
  quoting, one row per FoodItem). "Eksport CSV (Excel)" row added in
  Profile data section alongside the existing JSON action.
- Friend QR code: CIFilter.qrCodeGenerator-based QRCodeRenderer
  encodes `mealgram://friend/<id>`. "Pokaż mój kod" sheet from
  AddFriendSheet shows the QR + textual id with copy-to-clipboard.
- Onboarding celebration: new .celebration step after paywall —
  spring-in badge + pure-SwiftUI confetti (36 pieces over a
  TimelineView). Hides the progress header for full-bleed feel.
- Global meal search: MealSearchService scans all MealEntry rows by
  FoodItem.name. "Szukaj w historii" sheet groups results by day.
- Recipe URL importer: pure-Swift JSON-LD parser handles single
  object / array / @graph wrappers + three instruction shapes.
  "Importuj z URL" entry in the recipe library "+" menu.
- M4.11 / M1.11 progress: Localizable.xcstrings expanded 9 → 56
  entries with PL/EN/UK for tabs, greetings, common buttons,
  add-options menu, profile sections, coach copy, celebration,
  friends QR. CFBundleLocalizations now lists all three.
- MealEntry tags: free-form `tags: [String]` on the model (lightweight
  migration default-empty). MealRepository.updateTags trims + lowers
  + dedups. MealDetailSheet has a chip strip with the new FlowLayout
  + add/remove UI. MealSearchService matches by tag too.
- Achievements grown 14 → 21: streak.50, protein.week (7 days in a
  row hitting protein goal), recipes.ten, weight.ten, tag.first, the
  meta achievements.ten that fires alongside the 10th badge. Engine
  Inputs got 3 new counters for the totals.
- Profile streak calendar: month grid with logged days highlighted
  in primary, today stroked in accent. Prev/next month nav. New
  "Historia serii" row in preferences.
- Achievement unlock system notification: NotificationCoordinator gains
  notifyAchievement(_:) and fires alongside the in-app banner so
  backgrounded users still notice.
- Recipe importer reads prepTime + cookTime ISO-8601 durations from
  JSON-LD (PT30M / PT1H15M) — falls back to totalTime for cookTime.
- Haptics: Core/Utilities/Haptics enum wraps UIFeedbackGenerator.
  Fires on meal save, badge unlock, delete (warning), undo (light),
  freeze use, coach thumbs.
- Avatar picker: confirmationDialog gates camera vs library;
  CameraImagePicker is a UIImagePickerController wrapper with front-
  facing default + allowsEditing crop.
- Meal duplicate: "Duplikuj na dziś" copies a past meal as a fresh
  entry consumed at now. Refetches by id for cross-context safety;
  skips photoFilename so copies don't share JPEGs.
- Recipe favorites: isFavorite on Recipe + heart filter toolbar
  toggle + context-menu entry + small heart.fill on the row.
- MealEntry notes UI: TextEditor "Notatka" between tags + items in
  the detail sheet, persisted via MealRepository.updateNotes (trims +
  nil-on-empty).
- Recipe shopping list export: cart toolbar button on detail view
  raises ShareLink with plain-text "• ingredient" list including the
  current servings count.
- Recipe portion scaling: macro pills now multiply by the servings
  slider in real time; header switches between "Wartości / porcję"
  and "Wartości łącznie" with a × chip.
- Photo cleanup: MealRepository.photoIsOrphaned check + deferred 6s
  Task post-delete deletes the JPEG file once the undo window has
  passed, but only if no surviving meal references it.
- Polish food seed grown 78 → 104 with pizza pepperoni, kebab, sushi
  (California/Philadelphia), pad thai, ramen, gyros, chłodnik,
  granola, ciecierzyca/soczewica, tofu, and more.
- App Shortcuts (iOS 16+ AppIntents): "Dodaj posiłek", "Pokaż dziś",
  "Tygodniowe podsumowanie" — discoverable from Siri / Spotlight /
  Shortcuts app. Intents post NotificationCenter messages; MainTabView
  observes and routes.
- WidgetKit Home Screen widget: small + medium families showing streak
  + calories remaining + last-meal name. Snapshot via shared
  UserDefaults (suiteName: group.app.mealgram.shared, falls back to
  standard without entitlement). TodayState publishes on every refresh
  + reloadAllTimelines.

305 unit tests + 3 UI tests (1 pre-existing flake on Xcode 16
sim — testGoogleSignInTapShowsNotConfiguredBanner), swiftlint --strict
clean, swift-format clean. App + MealgramWidget appex both build.

Five tabs: Dziś • Dodaj • Tydzień • Znajomi • Profil.
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
2026-05-12 — long autonomous run, ~62 commits on `develop`. Closed Phase 1 entirely (auth, SwiftData v1, networking, onboarding, camera, Today, Profile, streaks, testing baseline, Worker code-complete), then most of Phase 2 (calibration manager, per-item edit + manual add, voice STT, barcode + OFF, Quick DB UI with 43-dish PL seed, achievements engine + grid, Weekly Progress tab) and selected Phase 3/4 (Recipe Library + cook-to-meal, suggested-recipe Today card, Polish cultural-event banner). Bonus: weight log + Apple Health read-only import, avatar picker, central A11yID catalog, `DebugBypass` for screenshot launches, ARCHITECTURE / CONTRIBUTING / README docs refresh. **129 unit + 3 UI tests green**, swiftlint --strict clean, swift-format clean. Next stoppers are external credentials — Supabase, Google OAuth, Cloudflare/Gemini, RevenueCat, Apple Team ID, physical iPhone.

2026-05-13 — another long autonomous polish run, ~50 features merged on `develop`. First half: BMR/TDEE onboarding goals, water tracking on Today, macro pie chart, recipe duplicate, theme picker, Help/FAQ sheet, Spotlight indexing recipes, app-version footer, recipe rating UI + ratingDesc sort, MacroSplit presets in EditGoals, onboarding restart from Profile, Today date scrubbing with chevrons + DateJumpSheet, meal photo zoom (pinch + pan), achievement detail sheet + share card, calibration reset, friend share-link in MyCodeSheet, recipe ingredient cook-mode checkboxes, cultural event dismissal, streak explanation modal, achievements earned-only filter, food seed 104 → 129, custom food creation in Quick DB, avatar reset, Today date picker jump, Quick DB long-press quick-log, recipe cooking timer, weight goal RuleMark + editor, CSV export date range, "Pomiń na razie" onboarding skip, weight row tap-to-edit, MealEntry tag autocomplete, lifetime stats total kcal, coach history helpful filter, reset Quick DB recents. Second half: editable daily water goal, BMI card on weight view, tap-Cel calorie-goal editor on Today, "N dni z nami" precise day count, MealRepository.updateConsumedAt + DatePicker in detail sheet, undo window 5s → 8s, calorie ring goes gold at goal / red past 120%, MealRepository.cleanupOrphanedPhotos + Profile sweep button, recipe ingredient clipboard copy, WeightService.sevenDayAverageKg in summary, tap-tab-again scroll-to-top on Today, recipe URL import clipboard auto-paste, total cooked-recipes lifetime stat, MealEntry.rating + 1-5 star UI in detail sheet. swiftlint --strict clean, swift-format clean, unit tests green (1 pre-existing UI flake unchanged).
