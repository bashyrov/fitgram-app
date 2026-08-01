# Mealgram i18n audit — unverified surfaces

Generated 2026-05-28. Status per screen across 5 langs (en/pl/uk/ru/es).

Legend:
- ✅ verified via simulator screenshot
- 🟡 routed through L()/LocalizedStringKey + xcstrings has translations (logically correct)
- ⚠️ NOT verified visually + may have hardcoded leaks
- ❌ broken / known issue

---

## 1. Share / export screens

| Surface | Status | Notes |
|---|---|---|
| Streak share card | ✅ EN/RU verified | `StreakShareCard.swift` |
| Achievement share card (1080×1920 PNG) | ⚠️ | `AchievementShareCard.swift` — needs check on render output |
| Shopping list share (Recipe) | 🟡 | Fixed Subject string but not visually confirmed |
| Recipe modifications bullet-list share | ⚠️ | `RecipeModificationsSheet.swift:bulletList` |
| Friend QR share | ⚠️ | `MyCodeSheet.swift` invite message |
| CSV export (Excel) | ⚠️ | `MealCSVExportService.swift` headers are Polish |
| JSON export | ⚠️ | `DataExportService.swift` — keys/labels |
| ZIP bundle export | ⚠️ | `DataBundleExportService.swift` |

## 2. Onboarding flow (7 steps)

⚠️ ENTIRELY UNVERIFIED — DebugBypass skips this.

- Welcome step
- Goal step
- Activity step
- Calibration step
- Dietary preferences step
- Paywall step
- Celebration step
- AccountStepView (email/Google/Apple)

Files:
- `Mealgram/Features/Onboarding/Steps/*.swift`
- `Mealgram/Features/Onboarding/OnboardingFlow.swift`
- `Mealgram/Features/Onboarding/OnboardingView.swift`

## 3. Subscription / paywall

⚠️ Currently disabled (`IS_PAYMENTS_ENABLED=false`) but code paths exist.

- `UpgradeSheet.swift` — paywall with 2 plans, auto-renew disclosure, restore button
- `PaywallTrigger.swift` — 13 trigger Copy structs (headline + body + badge)
- `StoreKitSubscriptionService.swift` — PurchaseError descriptions
- Free-tier limit caps + upsell cards in Favorites, Recipes, Friends, Goals, History, Export

## 4. Add meal flow

Add Meal Sheet (5 options) — partial verify needed:
- Photo scan tile
- Barcode tile
- Voice tile
- Quick Database tile
- Favorites tile
- Manual entry pill

Files: `AddMealSheet.swift`

## 5. Photo scan → Scan result flow

⚠️ Multi-step:
- Camera capture view
- Loading / "scanning..." state
- ScanResultView (detected items + macros + edit + save)
- "Add manually" path

Files:
- `Features/Camera/CameraCaptureView.swift`
- `Features/Camera/ScanResultView.swift`

## 6. Barcode flow

⚠️ Multi-state:
- Scanner active overlay
- Product found view (BarcodeProductView)
- Not found view (BarcodeRootView .notFound)
- Error view

Files: `Features/Barcode/Views/*.swift`

## 7. Voice flow

⚠️ Several stages:
- Permission gate
- Idle (Tap to talk)
- Listening (partial transcript)
- Finished → ConfirmationView (transcript editor + portion sliders)
- Error states

Files: `Features/Voice/Views/*.swift`

## 8. Quick Database

⚠️ Multiple sub-flows:
- Search field
- Category chips
- "Last picked" + "Frequent" horizontal carousels
- Food row + portion picker sheet
- CustomFoodFormSheet (add custom food)
- LabelScannerSheet (Vision OCR scan label)

Files: `Features/QuickDatabase/Views/*.swift`

## 9. WhatsNew sheet

⚠️ Version-bump release notes screen.

Files: `Features/WhatsNew/WhatsNewSheet.swift`

## 10. Friend profile sub-tabs

⚠️ Goals / Stats / Reactions tab content within FriendProfileView.

Files:
- `Features/Friends/Views/FriendProfileView+GoalsTab.swift`
- `Features/Friends/Views/FriendProfileView+StatsTab.swift`
- `Features/Friends/Views/FriendProfileView+ReactionsTab.swift`

## 11. Weekly Debrief sheet ("Co u Ciebie")

⚠️ Opens from Today between insight + meals.
- Headline ladder (Cudowny / Solidny / Mieszany / łapać rytm)
- Stats grid (5 cards)
- Full insight list
- Helpful thumbs row
- Clock toolbar → CoachHistoryView

Files:
- `Features/Coach/WeeklyDebriefView.swift`
- `Features/Coach/CoachHistoryView.swift`

## 12. Meal detail / edit flow

⚠️ Tap any timeline row:
- Photo header (if any)
- Portion slider + commit
- Date/time edit (DatePicker)
- Notes TextEditor
- Tag chips (FlowLayout)
- Rating 1-5 stars
- Duplicate / Delete actions

Files: `Features/Today/Components/MealDetailSheet.swift`

## 13. Recipe sub-screens

⚠️ Multiple:
- RecipeListView (filtered count, sort menu, "Co podobnego?" carousel)
- RecipeFormSheet (create/edit, nutrition estimator, ingredient editor)
- RecipeDetailView (header, ingredients, instructions, servings scaler, shopping list, modifications)
- RecipeModificationsSheet
- RecipeImportSheet (URL paste / clipboard auto-paste)

Files: `Features/Recipes/Views/*.swift`

## 14. Profile sub-screens

⚠️ Multiple sheets:
- EditGoalsView + EditGoalsSheets (8 goal sheets)
- WeightLogView (BMI card, trend chart, manual entry)
- DayMealsSheet (heatmap day drill-down)
- HelpFAQSheet
- LegalSheet
- AvatarPicker
- StreakCalendarSheet
- StreakSharePreviewSheet
- PrivacySettingsSheet
- CSVExportRangeSheet
- AchievementDetailSheet (with share card)

## 15. Settings sub-screens

⚠️
- SettingsView root (gear icon from Profile)
- LanguageSettingsView
- PreferencesView (notifications toggles)
- "Restart onboarding" alert

## 16. Auth flow

⚠️ Not normally seen (Apple Sign In direct):
- AuthView (3 buttons: Apple/Google/Email)
- EmailSignInSheet
- AccountStepView (in onboarding)

## 17. Calibration view

⚠️ One-off after first photo scan + accessible from Profile.

Files: `Features/Calibration/CalibrationView.swift`

## 18. Achievements

⚠️
- AchievementsSection (grid in Profile)
- AchievementDetailSheet
- Unlock banner (transient toast)
- 21 catalog entries (titles + summaries — these ARE in xcstrings)

## 19. Notifications surface

⚠️
- Local notification body text (NotificationPlanner)
- Notification scheduling labels
- Achievement notification body

## 20. AI / Worker integration

🟡 **Locale wiring fixed** in 4 places (Coach, Recommendations, Food, FoodDetector) — now sends user-selected language to Worker. Worker prompts Gemini in that language.

But: actual response content depends on Gemini. If Gemini gives a bad translation or returns mixed-language text, that's a runtime quality issue not a code issue.

Surfaces:
- Daily Coach insight (Today + OlaTipsView) — from Worker
- Weekly Debrief — from Worker
- Recommendations (onboarding plan) — from Worker
- Scan-food (Photo → Gemini Vision) — locale sent
- Voice meal parser — local PL regex only, no AI

## 21. Cultural event banner

⚠️ 12 events × name/summary/foodNote — all wrapped via L() in `CulturalEvent.swift`. xcstrings has translations. Need visual verify.

## 22. Live Activity / Dynamic Island

⚠️ Visible during meals/water tracking.

Files: `Features/Today/Components/LiveActivity*.swift`, `MealgramWidget/MealgramLiveActivity.swift`

## 23. Widget extension

⚠️ 4 widget families:
- CalorieRingWidget
- StreakWidget
- WaterWidget
- TodayMealsWidget

⚠️ Widget extension does NOT share the L() helper (separate Bundle). Widget strings use `String(localized:)` which uses system locale, not app-selected locale.

## 24. App Shortcuts (Siri / Spotlight)

⚠️ MealgramIntents — uses LocalizedStringResource which honors system locale, NOT app-selected. So Siri responds in iPhone language. Acceptable per Apple guidance.

## 25. Hardcoded interpolations remaining

39 sites identified earlier with `L("…\(var)…")` — these don't look up correctly because the runtime-rendered string is used as key. Most are in:
- `RuleBasedCoach.swift` (9 sites)
- `RuleBasedRecommendationsService.swift` (10 sites)
- `WeightLogView.swift`, `SettingsView.swift`, `RecipeFormSheet.swift`, etc.

Should convert to `String.localizedStringWithFormat(L("…%@…"), value)`.

---

## Priority for fixing (most user-visible first)

1. **AI responses end-to-end** — make sure Worker locale fix actually flows through every call site
2. **Onboarding** — first thing new users see
3. **Add meal sheet + 5 entry flows** — daily usage
4. **Meal detail sheet** — common interaction
5. **Recipe sub-screens** — Phase 2 feature
6. **Settings + Profile sub-sheets** — preference changes
7. **Achievements unlock banner** — celebratory moment
8. **Friend profile tabs** — social feature
9. **Weekly Debrief** — weekly engagement
10. **Cultural event banner** — Polish market feature
11. **CSV/JSON/ZIP export** — labels in archive
12. **Share cards** — virality
13. **39 interpolation sites** — coach fallback strings
14. **Widget strings** — home screen
15. **WhatsNew sheet** — version bumps
16. **Calibration view** — rare
17. **Auth flow** — first time only
18. **Live Activity** — rare
