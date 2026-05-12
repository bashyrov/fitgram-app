# Mealgram Architecture

## Tech Stack

| Layer          | Choice                                            | Rationale                                              |
|----------------|---------------------------------------------------|--------------------------------------------------------|
| Language       | Swift 5.10, strict concurrency                    | Memory safety + actor isolation for AI/IO heavy paths  |
| UI             | SwiftUI (iOS 17+), Observable, NavigationStack    | Modern declarative, less ceremony than UIKit           |
| State (simple) | Observable macro (MV pattern)                     | Minimal boilerplate for read-mostly screens            |
| State (complex)| TCA (Composable Architecture)                     | Camera capture, Recipe parsing, Coach chat             |
| Persistence    | SwiftData                                         | First-class SwiftUI integration, schema migrations     |
| Backend        | Supabase (Postgres+Auth+Storage+Edge Fn+pgvector) | Managed, EU region for RODO/GDPR                       |
| AI proxy       | Cloudflare Workers + Upstash Redis cache          | Keys never on device, rate limit, image-hash cache     |
| Vision         | Gemini 2.5 Flash (default), Pro (premium)         | Cheapest accurate vision; Pro fallback for tough cases |
| Chat           | Claude Sonnet 4.5                                 | Best EQ/safety tone for "Ola" coach                    |
| Subscriptions  | RevenueCat                                        | Hides StoreKit complexity, trial + restore handled     |
| Analytics      | PostHog (EU host)                                 | Self-serve dashboards + feature flags                  |
| Errors         | Sentry                                            | iOS SDK quality, source-mapped stacks                  |
| Build          | xcodegen → Xcode project                          | Reproducible, code-reviewable project config           |

## Key Patterns

- **MV** for read-mostly screens (Today, Profile, Progress).
- **TCA** was intended for Camera / Coach / Recipe parsing; in practice the
  scope of each turned out small enough that `@Observable` state machines
  + injected services match the same shape with less ceremony. TCA stays
  in the toolbox if a flow grows beyond what MV + services handles cleanly.
- **Repository** between SwiftData and feature modules.
- **Protocol-oriented services** for dependency injection and testability.
  Every external surface (HealthKit, food catalog, barcode lookup, meal
  save) is fronted by a protocol so tests can swap an in-memory stub.
- **`MealSaving` as the side-effect spine** — every meal-entry path
  (photo, barcode, quick-db, voice, recipe) writes through this protocol;
  `ChainedMealSaver` in `RootView.swift` is the single place where
  streak / achievement / calibration side-effects fan out.
- **Coordinators** — `AppRouter` is the only navigation coordinator;
  every other surface uses `NavigationStack` + `sheet` / `fullScreenCover`.

## Module map

```
Mealgram/
├── App/                     composition root + routing
│   ├── MealgramApp.swift    @main, builds every service + state
│   ├── AppRouter.swift      AuthSession.phase → launching|anonymous|onboarding|main
│   ├── RootView.swift       routes by AppRouter.phase + hosts ChainedMealSaver
│   └── MainTabView.swift    Today/Add/Progress/Profile + 5 entry sheets
├── Core/
│   ├── Models/              @Model SwiftData rows (User, MealEntry, FoodItem,
│   │                        Food, Recipe, RecipeIngredient, Calibration,
│   │                        Streak, Achievement, WeightEntry)
│   ├── Persistence/         MealgramSchemaV1 + PersistenceController
│   ├── Networking/          APIClient + Endpoint + interceptors + RetryPolicy
│   ├── Services/
│   │   ├── Auth/            AuthService + AppleAuthProvider + stubs
│   │   ├── Achievements/    AchievementEngine + Service + UnlockBus
│   │   ├── Calibration/     CalibrationService
│   │   ├── HealthKit/       HealthKitService (read-only body mass)
│   │   ├── FoodCatalog/     FoodCatalogService + FoodSeeder + bundled JSON
│   │   ├── CulturalEvents/  Polish event calendar + Easter algorithm
│   │   ├── Keychain/        Keychain + TokenStore
│   │   ├── UserRepository · StreakService · DataExportService
│   │   ├── AccountDeletionService · AvatarStore · WeightService
│   └── Utilities/           Logger+, DebugBypass
├── DesignSystem/
│   ├── Tokens/              Palette, Font, Space, Radius, Motion, Shadow
│   ├── Components/          PrimaryButton, SecondaryButton, Card, EmptyState
│   ├── PressableButtonStyle.swift
│   └── AccessibilityIdentifiers.swift  central A11yID catalog
├── Features/                one folder per product surface
│   ├── Auth · Onboarding · Today · Camera · Barcode · QuickDatabase
│   ├── Voice · Recipes · Progress · Profile · Calibration · Weight
│   └── Achievements
├── Resources/               Assets.xcassets, Localizable.xcstrings, Seeds
└── Supporting/              Info.plist, Mealgram.entitlements, PrivacyInfo
```

## Save-path topology

Every `MealEntry` save flows through the same chain so behaviours stay
in one place:

```
Feature view (ScanState, BarcodeFlowState, QuickDatabaseRootView, …)
        │ try mealSaver.save(meal:)
        ▼
ChainedMealSaver (RootView.swift, @MainActor, private)
  │  1. If meal.source == .photoScan AND calibration.factor != 1.0
  │     → meal.portionMultiplier *= factor (M2.1)
  │  2. try underlying.save(meal:)            (real persistence)
  │  3. If source == .photoScan: calibrationService.recordSample()
  │  4. streakService.registerLog(userRemoteID)
  │  5. unlocks = achievementService.evaluate(userRemoteID)
  │  6. unlockBus.push(unlocks)               (overlay banner)
        ▼
SwiftDataMealSaver
        │ context.insert(meal); context.save()
        ▼
SwiftData store  (M1.2 schema v1.0)
```

`MainTabView.refreshAfterSave()` then re-pulls `TodayState` and
`ProgressState` so dashboards reflect the new entry.

## Service Architecture

```
┌────────────┐    ┌──────────────────┐    ┌────────────────────┐
│  iOS App   │ ←→ │ Cloudflare Worker│ ←→ │ Gemini / Claude    │
│ (SwiftUI)  │    │   (proxy+cache)  │    │ + Open Food Facts  │
└────┬───────┘    └────────┬─────────┘    └────────────────────┘
     │ JWT                  │ KV/Redis cache
     ↓                      ↓
┌────────────┐         ┌──────────┐
│ Supabase   │         │ Upstash  │
│ (Postgres) │         │  Redis   │
└────────────┘         └──────────┘
```

## Data Flow

1. User captures photo → AVFoundation pipeline → JPEG ≤ 1MB.
2. Worker request: `POST /api/v1/scan-food` with JWT + image (multipart).
3. Worker hashes image → checks Redis → either returns cached result or calls Gemini.
4. Worker returns normalized `FoodScanResult` JSON.
5. App writes `MealEntry` via SwiftData repository → optimistic UI → Supabase sync via Realtime.

## Decisions Log

### 2026-05-10: Bootstrap stack
**Context:** Pick stack for production iOS app targeting PL market.  
**Decision:** SwiftUI + SwiftData + TCA, Supabase, Cloudflare Worker proxy.  
**Rationale:** Apple-native stack maximizes long-term maintainability; managed backends keep solo dev velocity high; Worker keeps AI keys off the device and centralizes rate limiting.  
**Alternatives considered:** Firebase (worse EU data story), self-hosted Postgres (ops overhead), UIKit (slower velocity for non-trivial screens).  
**Consequences:** Locked to iOS 17+; vendor mix means more accounts to manage.

### 2026-05-10: Design direction "light & airy"
**Context:** User explicitly asked for "максимально легкий и приятный" design.  
**Decision:** Warm cream backgrounds, soft sage as primary, coral accent. Heavy use of whitespace; large corner radii (16–24); SF Pro Rounded; soft shadows; no harsh reds anywhere.  
**Rationale:** Diet/calorie apps are inherently judgmental; calm, food-safe palette and generous breathing room reduce shame triggers and improve daily-open rate.  
**Alternatives considered:** Bold neo-brutalist (high recall, but adds stress), dark-first (loses warmth).  
**Consequences:** All charts/progress must work in low-saturation palette; need extra care for WCAG AA contrast.

### 2026-05-12: MealSaving as the single side-effect spine
**Context:** Multiple feature paths (photo scan, barcode, voice, quick DB) save meals; downstream consumers (streak counter, achievements, calibration sample count, Today refresh) need to react to every save.  
**Decision:** `MealSaving` protocol stays minimal (`func save(meal:) throws` on `@MainActor`). `SwiftDataMealSaver` is the leaf; `ChainedMealSaver` (private to `RootView`) decorates it with streak / achievement / calibration / unlock-bus side effects in one place. Feature code only ever sees `any MealSaving`.  
**Rationale:** Keeps side effects testable (each service has its own unit-level coverage), eliminates the temptation to scatter `try? streakService.registerLog(...)` calls across the codebase, and gives us one obvious place to add post-save behaviours (e.g. Realtime sync to Supabase later).  
**Alternatives considered:** NotificationCenter post-save events (loses static typing), TCA `Effect` (heavy for what's currently a sync save), AccountDeletionService-style separate orchestrator (more files, no real benefit).  
**Consequences:** ChainedMealSaver fields grow with each new side effect, but that's a deliberate, code-reviewable single source of truth.

### 2026-05-12: Calibration applies only to AI-derived entries
**Context:** User-tunable `Calibration.portionAdjustmentFactor` is meant to compensate for the AI's portion bias. Barcode lookups and quick-database picks have user-confirmed portion values; voice entries are placeholders.  
**Decision:** `ChainedMealSaver` checks `meal.source == .photoScan` before scaling; only photo-scanned entries are calibrated, and only those bump the sample count on the Calibration row.  
**Rationale:** Silently multiplying a user-typed 200 g barcode portion would make the running totals untrustworthy; the calibration UI explicitly frames the slider as "if AI is usually off" so it should only affect AI.  
**Consequences:** Future entry types that go through AI (multi-item OCR, voice→Claude parsing) need to opt in by setting `source = .photoScan` or by widening the conditional.

### 2026-05-12: Quick Database backed by bundled JSON until Supabase lands
**Context:** Master prompt's M2.5 puts the catalog in Postgres with FTS; that's blocked on Supabase credentials.  
**Decision:** Ship a `FoodCatalog` protocol with two implementations — `FoodCatalogService` (SwiftData-backed, seeded from `polish_food_seed.json`) now, a Postgres-backed implementation later. UI talks to the protocol only.  
**Rationale:** Unblocks the Quick Database UX without waiting on Supabase, gives us a known-good local dataset for tests, and the protocol seam makes the swap mechanical.  
**Consequences:** The JSON is the single source of truth for the seed catalog; updating it requires a build (no OTA refresh) until M2.5 lands.

## API Contracts

### POST `/api/v1/scan-food` (Cloudflare Worker, M1.6)

**Request:** `multipart/form-data`
- `image`: JPEG/PNG, 1–6 MB
- `meal_type_hint` *(optional)*: `breakfast` | `lunch` | `dinner` | `snack`
- `premium` *(optional)*: `"true"` switches Gemini Flash → Pro

**Headers:** `Authorization: Bearer <supabase-jwt>` (HS256, verified server-side)

**Response 200:** `application/json` (snake_case → decoded into camelCase by `JSONDecoder.mealgram`)
```json
{
  "items": [{ "name": "...", "quantity_grams": 180, "calories_kcal": 420,
              "protein_grams": 32, "carbs_grams": 18, "fat_grams": 22,
              "confidence": 0.92 }],
  "suggested_meal_type": "lunch",
  "confidence": 0.89,
  "raw_ai_notes": null,
  "from_cache": false
}
```
Idempotent by SHA-256 of the raw image bytes; cached 7 days in KV / Upstash.

**Errors:** `401` missing/bad JWT · `413` image too large · `415` non-multipart · `502` Gemini upstream failure.
