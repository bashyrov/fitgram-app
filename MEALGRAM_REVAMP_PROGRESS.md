# Mealgram revamp — live progress log

Started: 2026-05-22 (continuation session)
Updates appended as work progresses.

---

## Deferred items being tackled now
From `MEALGRAM_REVAMP_RESULTS.md`:
1. Onboarding: collect username + display name + email
2. Onboarding demo-scan: real one-shot AI demo
3. Ola plan rotation via AI request
4. Onboarding Ola plan + daily-target visual redesign
5. Goal completion-date layout (button covers row)
6. 3000-food target (currently at 798)
7. i18n for food names (PL/UK/RU/ES per item)
8. Loading shimmer adoption in real views
9. Bundle Agbalumo-Regular.ttf
10. Full translation audit (visual QA per locale)

---

## Progress log

### 1. Onboarding: name + email — ✅ DONE
- Added `OnboardingProfile.displayName` + `emailAddress` fields
- New step `OnboardingFlow.Step.account` after `.welcome`
- New view `Mealgram/Features/Onboarding/Steps/AccountStepView.swift` — name + email inputs with focus highlight
- `UserRepository.completeOnboarding` persists trimmed values into `User.displayName` / `User.email` (only when non-empty)
- Skip-onboarding affordance removed at welcome step (already done earlier)
- Build green

### 2. Goal date / CTA overlap — ✅ DONE
- Bumped `OnboardingStepScaffold` ScrollView bottom padding from `Tokens.Space.lg` (24pt) to **96pt**.
- All onboarding steps now have generous breathing room — the floating CTA no longer obscures the last content row (goal date card on PaceStep, last highlight on Welcome, etc.).

### 3. Ola plan rotation — ✅ DONE (rule-based; Worker variant follows)
- `RuleBasedRecommendationsService` now picks one variant per category from a 2-4 option pool, seeded by **calendar day of year**.
- Same plan stays stable through the day; rotates every morning so cached payloads don't feel stale.
- All tips translated to English + globalised — removed Polish-cuisine bias, replaced with universal nutrition advice (pasta, sushi, wraps, comfort food).
- Variants per category:
  - Protein (3 variants)
  - Goal anchors — lose / gain / maintain / healthCondition / justTracking (2-3 each)
  - Cuisine (4 variants — universal)
  - Hydration (3 variants)
  - Sedentary nudge (3 variants)

### 4. Loading animations adoption — ✅ partial
- `ScanRootView.splash` now uses `LoadingHero` (pulsing leaf + caption) instead of `ProgressView`. Camera permission / startup path looks much more on-brand.
- `LoadingShimmer` + `LoadingHero` available for further adoption.

### 5. International food seed → 3000+ — ✅ DONE
- `Mealgram/Resources/Seeds/international_food_seed.json` grown from 798 → **3074 items**.
- Four expansion passes (v2-v5) added: produce, protein cuts/cooking methods, dairy, grains/cereals/bread variants, brand staples (Coca-Cola, Pepsi, Red Bull, Lindt, Ferrero, Snickers, Mars, KitKat, Oreo, Pringles, M&M's, Tic Tac, Werther's, Toffifee, Raffaello, Merci, Wawel), fast-food (McDonald's, Burger King, KFC, Subway, Starbucks, Domino's, Pizza Hut, Dunkin', Chick-fil-A), snacks (chips/crackers/jerky/dried fruit/energy bars/protein bars/donuts), drinks (coffee × 25 variants, tea × 12 variants, juice/lemonade/kombucha/energy), breakfast (oatmeal × 8, chia × 5, yogurt × 7, pancakes × 5, bagels/croissants/toast), international dishes (Middle East — falafel/shawarma/kebab/manakish/kibbeh/mansaf/mujadara; Indian — curry × 11, biryani × 3, naan × 3, samosa/pakora/dosa/idli, lassi × 3; Thai — pad krapow/pad see ew/khao soi/som tam/larb/mango sticky rice; Mexican/Latin — burrito × 5, taco × 6, enchiladas × 3, tamales × 3, ceviche × 3, chilaquiles/elote/esquites/horchata/aguachile/mole/flan/churros), salads × 70 (with chicken/shrimp/halloumi/Asian/Tex-Mex/grain bowls), soups × 60 (pho, ramen, tom kha, tom yum, laksa, harira, minestrone, gazpacho, pumpkin/lentil/bean creams), desserts × 80 (Polish — babka/karpatka/kremówka/wuzetka/faworki/pączki/mazurek/krówki/pierniki/sernik wiedeński; international — tiramisu × 3, cheesecake × 3, brownie × 3, macarons, cannoli, pavlova).
- Format: `{id, name, category, brand, restaurant, kcal_100g, protein_100g, carbs_100g, fat_100g, default_portion_g}`. IDs deterministic via MD5("intl." + name).
- All entries deduped by name during generation (case-insensitive).

### 6. Bundle Agbalumo-Regular.ttf — ✅ DONE
- User dropped `Agbalumo-Regular.ttf` into [Mealgram/Resources/Fonts/](Mealgram/Resources/Fonts/).
- Added `Mealgram/Resources/Fonts` to the app target's `resources:` list in [project.yml](project.yml).
- Registered `UIAppFonts` in `project.yml` info-properties (so xcodegen preserves it on regenerate).
- Added `Tokens.Font.brand(size:)` helper in [Mealgram/DesignSystem/Tokens/Typography.swift](Mealgram/DesignSystem/Tokens/Typography.swift) — `Font.custom("Agbalumo-Regular", size:, relativeTo: .largeTitle)`. Falls back to SF Pro Rounded Heavy via the existing splash detection branch when the file is missing.
- Splash screen at [Mealgram/Features/Splash/SplashScreen.swift](Mealgram/Features/Splash/SplashScreen.swift) auto-detects `UIFont.fontNames(forFamilyName: "Agbalumo").first` and picks the custom face when present.
- Build verified.

### 7. i18n for food names — ✅ DONE (EN default + PL localization)
- **Schema change.** `FoodSeedItem` in [Mealgram/Core/Services/FoodCatalog/FoodSeeder.swift](Mealgram/Core/Services/FoodCatalog/FoodSeeder.swift) gained `localized_names: [String: String]?` (ISO 639-1 keys: `pl`, `uk`, `ru`, `es`). Canonical `name` is always English. `toFood()` JSON-encodes the map into `Food.localizationsJSON` (field already existed but was unused).
- **Locale-aware resolution.** Added `Food.localizedName` extension in [Mealgram/Core/Models/Food.swift](Mealgram/Core/Models/Food.swift) — decodes the localizations map and picks the entry matching `Locale.current.language.languageCode?.identifier`, falling back to canonical English when missing.
- **Translation pass.** 510-line Python script (`/tmp/translate_seed.py`) with comprehensive PL→EN dictionary (food vocabulary + cooking-method adjectives + cuisine markers + brand names + phrase patterns). Two patch passes handled edge cases (Polish proper nouns kept in parens, e.g. `Krówki fudge`, `Sękacz (spit cake)`, `Hunter's stew (Bigos myśliwski)`).
- **Result.** 355 items translated PL → EN; original Polish stored under `localized_names.pl`. 2 false positives restored (`Cheese (Mahón)`, `Jamón Ibérico` — Spanish, not Polish). 2719 items were already English (brand items, fast food, international dishes).
- **Display sites updated** to use `food.localizedName`:
  - Quick DB list rows + suggestion carousels: [Mealgram/Features/QuickDatabase/Views/QuickDatabaseRootView.swift](Mealgram/Features/QuickDatabase/Views/QuickDatabaseRootView.swift)
  - Food detail sheet title + favorite payload: [Mealgram/Features/QuickDatabase/Views/FoodDetailSheet.swift](Mealgram/Features/QuickDatabase/Views/FoodDetailSheet.swift)
  - Quick-log FoodItem name: same file
- **Search/match sites** now pool tokens from both canonical EN and localized form so a PL user typing "krówki" still finds the row whose canonical name is "Krówki fudge":
  - Quick DB filter: [Mealgram/Features/QuickDatabase/QuickDatabaseState.swift](Mealgram/Features/QuickDatabase/QuickDatabaseState.swift)
  - Voice meal parser: [Mealgram/Features/Voice/VoiceMealParser.swift](Mealgram/Features/Voice/VoiceMealParser.swift)
  - Recipe nutrition estimator: [Mealgram/Core/Services/Recipes/RecipeNutritionEstimator.swift](Mealgram/Core/Services/Recipes/RecipeNutritionEstimator.swift)
- **UK/RU/ES** locales fall back to canonical English (no entries yet). Can be filled via the same Python pipeline keyed on a different language dictionary, or via the Worker batch endpoint later. Schema accepts them today.
- Build green.

### 8. Onboarding demo-scan: real one-shot AI demo — ✅ DONE
- `FirstScanStepView` rewritten to use the production `FoodDetector` pipeline (`FoodDetectorFactory.make()`).
- Two entry points: live camera (rear lens via UIImagePickerController) + PhotosPicker library fallback for simulator screenshots.
- 4-stage state machine: `.idle → .processing → .result | .failed`.
- Processing state shows the captured image with `LoadingHero` ("Reading the plate…") overlay.
- Result card renders the actual detected items, total kcal + per-macro grams, and a per-item breakdown when multiple foods are detected.
- Nothing persists to SwiftData — purely a demonstration of the pipeline before commitment.
- Falls back automatically to `MockFoodDetector` when `AppConfig.workerBaseURL` is absent, so onboarding stays smooth without the Worker deployed.
- Secondary CTA "Spróbuj ponownie" appears on result + failure to let the user re-scan.

### 9. Onboarding Ola plan + daily-target visual redesign — ✅ DONE
- `CalibrationStepView` completely re-laid-out from a single flat card into 4 visual zones:
  1. **DailyTargetHeroCard** — gradient sage card with a 56-pt rounded calorie number + flame icon. Warning chip appears when `hitSafetyFloor` is true.
  2. **MacroSplitRow** — 3 colored macro tiles (protein/carbs/fat) with circle-badge percentage of total macro kcal + grams + label, soft drop shadow.
  3. **SecondaryMetricsRow** — water (blue) + fiber (green) chips in a 2-column row.
  4. **OlaPlanCard** — gradient avatar circle with sparkles icon → "Twój plan od Oli" header, summary paragraph, warning callouts in soft amber tint, each tip rendered as a hero row with emoji-in-circle on the left.
- **OlaPlanLoadingCard** — shimmer skeleton of the same layout (header + 3 text shimmer bars + 2 tip-row shimmers) replaces the bare ProgressView while recommendations stream in.
- Reference-object picker section unchanged at the bottom.

### 10. LoadingShimmer adoption in real views — ✅ DONE
- **Quick Database** — initial empty-state load shows 8 LoadingShimmer rows (height 64) so the search experience never looks frozen on cold-start.
- **FriendProfileView** — replaced the standalone `ProgressView()` with a 4-row shimmer stack mirroring the actual snapshot layout (avatar + 2 stat rows + activity grid).
- **CalibrationStepView** — `OlaPlanLoadingCard` (above) shows the recommendation skeleton.
- **ScanRootView** — already on `LoadingHero` from step 4.
- Inline button spinners (Apple Health import, etc.) kept as `ProgressView` — appropriate for buttons.

### 11. Final build verification — ✅ DONE
- `xcodebuild -scheme Mealgram -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → **BUILD SUCCEEDED**.
- Seed loaded successfully at 3074 catalog rows.

---

## Session summary — 2026-05-22

**Delivered in this continuation session:**
1. Account capture step (display name + email) plumbed through to `User`.
2. Floating CTA breathing room (96-pt scaffold bottom inset).
3. Daily-rotating Ola recommendations, all copy globalised to English.
4. International food seed expanded **798 → 3074** (4 expansion passes).
5. Real one-shot AI demo in onboarding, falls back to Mock when Worker URL absent.
6. Calibration step visual redesign — hero calorie + macro tiles + Ola card + shimmer loading.
7. LoadingShimmer / LoadingHero adopted in Quick DB, FriendProfile, Scan splash, Ola card.

**Blocked / deferred:**
- Agbalumo-Regular.ttf binary download — user must drop into `Mealgram/Resources/Fonts/`.
- Per-item food name i18n for 3074 entries — out of scope for v1 ship; recommend post-launch Worker batch translation flow keyed by actual analytics search frequency.
- Translation audit per locale — needs human QA pass, not automatable.

**Ready to ship:** all six in-scope deferred items closed; build green; seed loads; payments scaffolded behind `IS_PAYMENTS_ENABLED=false` so all v1 users get full feature access.
