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

### 2026-05-13: SwiftData lightweight migrations are append-only
**Context:** Phase 1 shipped MealgramSchemaV1 with no migration plan. Every new feature in this session that touched the schema (MealEntry.rating, MealEntry.tags, MealEntry.notes, User.dietaryPreferencesRaw, CoachMemoryNote, WaterEntry, etc.) needs to land without invalidating existing user installs.  
**Decision:** Stick to lightweight migration: add optional / default-valued properties, never rename or remove. For sets / lists too complex for SwiftData (dietary preferences, future tag groupings), encode as comma-joined raw strings on the model and expose typed accessors via extensions.  
**Rationale:** No `SchemaMigrationPlan` boilerplate, no Phase 2 schema-version bump. Future LLM features (M3.1 Claude, M3.2 memory) get their own models added the same way.  
**Consequences:** Comma-joined strings sort alphabetically on save and lose insertion order — fine for sets, not fine for ordered lists. Any breaking schema change still triggers a versioned migration step; we'll bump SchemaV1 → SchemaV2 when that happens.

### 2026-05-13: M2.5 photo-OCR ships as local Vision before the Worker is wired
**Context:** Master prompt's M2.5 originally targeted a Worker-side OCR + nutrition extraction pipeline; that path is blocked on Cloudflare credentials.  
**Decision:** Build `FoodLabelScanner` against Apple's Vision (`VNRecognizeTextRequest`) + a pure-function `NutritionLabelParser` that handles Polish + English labels with regex extraction of kcal/protein/carbs/fat per 100 g. Wire into `Quick Database → "Zeskanuj etykietę"` raising a Vision-backed flow that prefills `CustomFoodFormSheet`.  
**Rationale:** Zero credentials needed, runs entirely on-device, ships actual value to users today. The Worker-side path can either replace or co-exist later for non-Polish labels or complex multi-language packaging.  
**Consequences:** Accuracy is bounded by Vision's recognition quality on photographed labels; failure case lands on a "spróbuj ponownie" empty state. Parser is the pure-function seam tests pin down.

### 2026-05-13: M3.2 Coach memory stored locally, no LLM yet
**Context:** Master prompt's M3.2 calls for "Ola's memory" — long-lived facts the coach references in future prompts. The Claude-backed generator (M3.1) needs a stable storage API to read/write against.  
**Decision:** Ship `CoachMemoryNote` (@Model) + `CoachMemoryStore` now: observation/preference/milestone/goal kinds, 0–1 confidence, case-insensitive upsert by summary text. Rule-based generator doesn't write notes; Claude-backed generator will.  
**Rationale:** When credentials arrive, the LLM has somewhere to land its observations without forcing a schema migration mid-launch. Tests pin down the upsert + confidence-averaging behaviour so the swap is mechanical.  
**Consequences:** Storage assumes summaries are short freeform Polish strings; if the LLM produces structured slots later we'll widen the model rather than reinterpret existing rows.

### 2026-05-13: M3.3 modifications surface text-only suggestions before LLM
**Context:** Master prompt's M3.3 wants AI-driven recipe modifications (lighter, more protein, gluten-free, dairy-free). That ideally calls Claude with the full recipe context.  
**Decision:** `RecipeModificationEngine` returns deterministic text suggestions based on ingredient-substring rules per intent. UI shows them in a sheet with per-suggestion clipboard + share. No auto-apply yet — user copies into their own edit.  
**Rationale:** Gets real value out of the feature today without an LLM dependency; the rule book doubles as gold-standard test fixtures for the eventual LLM diff.  
**Consequences:** Rule book is in Polish + assumes Polish recipe ingredient naming. Need to widen for EN/UK once localisation expands beyond the current 56-string catalog.

### 2026-05-13: ZIP exports via NSFileCoordinator, no third-party dependency
**Context:** Multi-entry archive of JSON + CSV + photos for GDPR / portability. iOS doesn't expose a public `Archive` API; `Compression` is single-stream only.  
**Decision:** Use `NSFileCoordinator.coordinate(readingItemAt:options:[.forUploading])` — the Apple-blessed way to materialise a directory as a temp `.zip`. Copy out into `tmp/exports/` so the URL outlives the coordinator callback.  
**Rationale:** Zero new dependencies, works back to iOS 11, no need to vend a `zip` lib through SPM.  
**Consequences:** No control over compression level / encryption; encrypted exports (if ever needed) require switching to a real zip lib.

### 2026-05-13: Mifflin-St Jeor over Harris-Benedict / Katch-McArdle for BMR
**Context:** Daily calorie target needs a reproducible BMR formula. Three are commonly used: Harris-Benedict (1919, revised 1984), Mifflin-St Jeor (1990), and Katch-McArdle (lean-mass-based).  
**Decision:** Mifflin-St Jeor for all sex/age/height/weight branches. Activity multiplier picks one of {1.2, 1.375, 1.55, 1.725, 1.9}; goal adjustment subtracts/adds 1100 kcal per kg/week pace, with sex-specific safety floors (1200/1500 kcal) clamping aggressive deficits and surfacing a `hitSafetyFloor` flag to the UI.  
**Rationale:** Mifflin-St Jeor has the best validation against indirect calorimetry in non-athlete adults; it's the formula every credible nutrition app ships. Katch-McArdle would be more accurate but requires bodyfat %, which our onboarding doesn't collect. Pure-function `GoalCalculator` with 39 unit tests pinned to reference numbers so future re-tuning needs to break a test on purpose.  
**Consequences:** Underestimates for very lean / athletic users (would need Katch-McArdle); we surface the override flags so they can manually pin a higher kcal target. Safety floor is non-negotiable — clamping happens before macro split, so even if the user picks 1 kg/wk on a 60 kg frame they still get a viable plan.

### 2026-05-13: Privacy-first social model — default fully private, opt-in per field
**Context:** Friends feature lets users share streaks, achievements, weekly stats, recipes, and (optionally) weight/height/meal details. Misconfigured defaults could leak sensitive health data.  
**Decision:** `PrivacySettings` starts at `.privateOnly` with every per-field toggle off. Visibility tier (`private` / `friends` / `public`) is the outer gate; per-field booleans are the inner gates. Supabase RLS enforces the same model server-side via `can_view_profile(viewer, owner)` helper — no client query can bypass it. A signup trigger seeds a default-private row for every new auth user so silent sign-ups don't leak. Sensitive fields (weight, height, meal details) live in a separate UI card so the user explicitly opts in.  
**Rationale:** Health data + social mechanics is a high-stakes combination. "Off by default, on by intent" is the only model where a confused user can't accidentally publish their weight. Symmetric blocks complete the picture — blocked-user can't observe viewer either, neither can pull a snapshot.  
**Consequences:** Onboarding can't show off the social mechanics without an extra opt-in step; we trade discoverability for safety. RLS policies are the single source of truth — iOS-side projection in `FriendProfileSnapshot` is a presentation convenience, not a security boundary.

### 2026-05-13: Friends ship against InMemoryFriendService now, Supabase schema ready
**Context:** Supabase URL + anon key are still pending. Spec asks for fully working social layer.  
**Decision:** Ship `InMemoryFriendService` extended to deliver realistic snapshots, blocks, reactions, reports. The same `FriendService` protocol gets a `SupabaseFriendService` once creds arrive. Full SQL migration (`supabase/migrations/20260514_social_layer.sql`) committed now so the backend lands as a `supabase db push` — 7 tables, helper functions (`user_pair` / `are_friends` / `is_blocked` / `can_view_profile`), full RLS, default-private trigger.  
**Rationale:** UI ships value today without a "coming soon" placeholder. SQL is reviewed + version-controlled so the eventual deploy is a no-surprise migration. Composition root flips from `InMemoryFriendService` → `SupabaseFriendService` in one line.  
**Consequences:** In-memory backend isn't shared between devices and resets on app reinstall; we lose the social layer entirely in development without seeded fixtures (already handled). Reactions / blocks survive process restart only via UserDefaults — chosen consciously so testing the privacy-first UI doesn't need a backend.

### 2026-05-13: AI Coach ships rule-based fallback now, Worker primary later
**Context:** Onboarding wants Ola's recommendations after the user finishes their profile. Worker URL + Claude key are pending.  
**Decision:** `RuleBasedRecommendationsService` is the always-shipping fallback — 8 prioritised rules (safety floor, pace warning, goal-anchor, protein adequacy, sedentary nudge, Polish-cuisine reassurance, hydration prompt, dietary preference echo) capped at 5 tips. `WorkerRecommendationsService` is the production primary that activates as soon as `AppConfig.workerBaseURL` is non-nil. Composite `RecommendationsService` tries primary, logs + falls back on any error, marks the response source so debug surfaces can tell which path served the tips.  
**Rationale:** Rule-based output is deterministic, testable, and on-brand for the PL market (cites pierogi ruskie, żurek, polskie warzywa). When Claude is wired, identical UI contract — only the `source` field changes from `rule_based` → `worker_claude_sonnet_4_5`. Anonymised request body (no name, no auth id, no avatar) is the same on both paths.  
**Consequences:** Rule-based tips can't react to free-form user goals (just enum branches); Claude-backed tips will. Persisted `latestRecommendationsJSON` on User means re-running the onboarding wizard isn't required to refresh advice — we'll add a "Odśwież rady" button on Profile in a follow-up.

### 2026-05-13: Target override flags are per-axis, not a single mega-flag
**Context:** Users routinely want to lock in a specific calorie target while letting macros + water float with the calculator (e.g. dietician set 1850 kcal but app-calculated macros are fine). One bool would force "all or nothing".  
**Decision:** `User` row carries four independent override flags — `caloriesOverridden`, `macrosOverridden`, `fiberOverridden`, `waterOverridden`. `UserProfileService.recalculate` re-derives only the fields whose flag is false; "Wróć do zalecanych" resets all four.  
**Rationale:** Matches how real users think about their numbers — they don't customise as a unit. Per-axis means the calculator can keep working partially while the user owns the bits they care about.  
**Consequences:** Slightly more state to keep in sync; we centralise mutation through UserProfileService so every edit path flips the right flag and saves through one method.

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
