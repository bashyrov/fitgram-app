# Mealgram Functional Review TODO

Last review: 2026-08-01

## Review Summary

The app is feature-rich and the core meal logging paths compile. The highest remaining pre-production risks are external services, localization consistency, full end-to-end social/auth validation, and replacing synthetic Ola Chef catalog coverage with a fully curated data set. Payment/App Store issues are intentionally excluded unless they block non-payment flows.

## Phase 0 - Verification Baseline

- [x] Run Worker typecheck.
- [x] Run iOS device build.
- [x] Run focused AI/error/usage tests.
- [x] Run Worker quota/timezone tests.
- [~] Run full unit test suite.
- [~] Run UI smoke tests on simulator.
- [ ] Install on physical iPhone and smoke-test real camera, microphone, barcode, paywall presentation, and auth.

Blocked by user/device:
- Physical iPhone currently appears as `unavailable` in CoreDevice.

Latest verification notes:
- iOS device build passed after the current fix batch.
- Worker typecheck and Worker tests passed.
- Full unit suite before the Ola Chef catalog hookup: 488 tests, 1 failure (`OlaChefCatalog` had 312 dishes instead of 1000+).
- The missing Ola Chef generated catalog was connected after that failure; focused rerun compiled but Xcode simulator launch hung at `waiting for workers to materialize`, so it needs one clean simulator rerun.
- UI smoke test attempt still needs cleanup: current UI tests are partly stale against the redesigned onboarding/auth surfaces.

## Phase 1 - Critical Functional Integrity

### 1.1 Meal Save Flows

- [x] Remove silent `try?` from primary save paths.
- [x] Show user-facing error if repeated meal save fails.
- [x] Show user-facing error if undo restore save fails.
- [x] Show user-facing error if quick database save fails.
- [x] Show user-facing error if recipe cook/save fails.
- [x] Show user-facing error if recipe duplicate/rating/favorite/delete fails.
- [x] Show user-facing error if voice commit fails.
- [x] Replace silent profile/settings/weight writes where user expects persistence.
- [ ] Continue persistence-error audit for favorites and secondary profile utilities.
- [ ] Verify every add path ends on grams review before final save:
  - [ ] Photo.
  - [ ] Voice.
  - [ ] Manual.
  - [ ] Quick database.
  - [ ] Favorites.
  - [ ] Recipes.
  - [ ] Ola Chef.
  - [ ] Barcode: simple gram slider only, no detailed AI.

### 1.2 AI Limits and Error States

- [x] Worker has hidden 60/day AI safety cap.
- [x] Worker has free/pro server-side limits for refresh/product/Ola Chef.
- [x] App sends timezone headers to Worker.
- [x] Worker uses user local day when timezone offset is present.
- [x] Photo draft scan no longer consumes the visible "3 saved AI meals" limit.
- [x] Add tests for Worker timezone day-window calculation.
- [x] Add tests for draft scan not counting toward free logged-meal quota.
- [ ] Make product nutrition cache per-100g instead of full raw text.
- [ ] Store AI-inferred products with normalized multilingual names.

### 1.3 AI Availability UX

- [x] Dedicated user message for AI temporarily unavailable.
- [x] One soft retry for Gemini failures.
- [ ] Add a reusable in-app AI unavailable panel for photo/voice/manual/Ola Chef failures.
- [ ] Add "add manually" CTA to AI unavailable states.

## Phase 2 - Backend Readiness

### 2.1 Friends

- [ ] Verify `SupabaseFriendService` is active when Supabase env is configured.
- [ ] Add visible warning in debug/internal builds when app falls back to `InMemoryFriendService`.
- [ ] End-to-end test:
  - [ ] Search by username.
  - [ ] Send request.
  - [ ] Accept request.
  - [ ] Open friend profile.
  - [ ] React to achievement/feed item.
  - [ ] Leaderboard updates.
  - [ ] QR add works beyond UI-only state.
- [ ] Replace any remaining local-only QR assumptions with backend-backed flow.

Blocked by user:
- Requires valid Supabase project URL and anon key with expected schema/data.

### 2.2 Auth

- [ ] Apple sign-in on physical device.
- [ ] Google sign-in with real OAuth client and URL scheme.
- [ ] Email magic link through Supabase.
- [ ] Auth error copy for all providers.
- [ ] Delete account server wipe through Supabase function.

Blocked by user:
- Requires Google OAuth client, Supabase env, and physical-device verification.

### 2.3 Account Deletion

- [ ] Verify `supabase/functions/account` secrets are present.
- [ ] Verify server-side user/data deletion.
- [ ] Replace "Server is not configured" with polished app-facing recovery.

Blocked by user:
- Requires Supabase deployment/secrets.

## Phase 3 - Localization and Copy

### 3.1 Full UI Localization

- [ ] Audit hardcoded `Text("...")`, `Button("...")`, `PrimaryButton(title:)`, `SecondaryButton(title:)`.
- [ ] Ensure all visible strings are covered in `Localizable.xcstrings`.
- [ ] Verify all five languages:
  - [ ] Polish.
  - [ ] English.
  - [ ] Ukrainian.
  - [ ] Russian.
  - [ ] Spanish.

Priority screens:
- [ ] Voice review.
- [ ] Recipe forms/details.
- [ ] Favorites.
- [ ] Settings/Profile.
- [ ] Friends.
- [ ] Ola Chef.
- [ ] Paywall/upgrade.
- [ ] Notifications.
- [ ] Achievements.
- [ ] Facts/Ola.

### 3.2 Content Localization

- [ ] Facts translated and culturally clean across all languages.
- [ ] Ola tips translated across all languages.
- [ ] Achievements translated across all languages.
- [ ] Notification titles/bodies translated across all languages.
- [ ] Ola Chef dish names and ingredients translated per app language.

## Phase 4 - Design and Interaction Polish

### 4.1 Visual Consistency

- [ ] Re-scan screens for hard gradient edges/bands.
- [ ] Verify all bottom fixed-button backgrounds blend into screen background.
- [ ] Verify profile/friends/week/facts/add screens match the current premium iOS direction.
- [ ] Verify empty states and paywall-locked blocks have consistent Pro treatment.

### 4.2 Microinteractions

- [ ] Add/verify haptics on day switch, add meal, AI refresh, product completion, friend reaction.
- [ ] Smooth date transitions on Today.
- [ ] Loading states for photo/voice/manual AI.
- [ ] Avoid layout jumps when AI result replaces local data.

## Phase 5 - Data Quality

### 5.1 Food and Dish Library

- [~] Remove synthetic duplicate dishes that only change cuisine label.
- [ ] Keep broad international coverage, not just Polish dishes.
- [ ] Ensure concrete ingredients, no generic "main protein", "vegetables", "sauce".
- [ ] Keep per-100g nutrition coherent and physically plausible.

Notes:
- Ola Chef now includes the large generated international catalog so the library is 1000+ entries.
- Suggestions de-duplicate generated template families so the same dish is not shown as multiple cuisines in the visible list.
- The generated portion is still a bridge, not final production content; replace it with curated real classic dishes over time.

### 5.2 Ola Chef

- [ ] Add final grams review before saving.
- [ ] Add large paginated/expandable suggestion list.
- [ ] Add filters: calories, meal type, cuisine, time, protein focus.
- [ ] Add AI fallback only when local library has weak coverage.
- [ ] Keep free limit disabled if product decision remains "unlimited for now".

## Phase 6 - Observability and Cost Protection

- [x] Add Worker tests for quota grouping.
- [ ] Add Worker tests for cache hits costing zero.
- [ ] Add admin dashboard checks for AI usage.
- [ ] Add Sentry breadcrumbs for AI failures, save failures, auth failures.
- [ ] Add PostHog events for add flow funnel, AI limits, paywall presentation.

## Work Started Automatically

- [x] Replace high-risk silent save failures in add/recipe paths with visible errors.
- [x] Add focused tests for Worker quota/timezone behavior.
- [x] Run Worker tests/typecheck and iOS device build after fix batch.
- [x] Connect Ola Chef generated international catalog.

## Completed in This Pass

- Quick database, voice, repeated meal, undo restore, recipe cook, recipe duplicate/rating/favorite/delete now surface a visible save error instead of silently failing.
- Recipe rating/favorite/cook UI mutations are rolled back when persistence fails.
- Avatar save/delete now shows a localized error and preserves the old photo if persistence fails.
- Account deletion and onboarding replay now surface localized errors instead of silently failing.
- Meal photo persistence and streak-freeze reconciliation now log failures instead of swallowing them.
- Ola Chef generated international catalog is now included in the app catalog; visible suggestions still de-duplicate same-template cuisine variants.
- Worker exports and tests now cover timezone-local day windows and quota endpoint grouping.
- Worker typecheck passed, Worker tests passed, iOS device build passed.

## Notes from Code Review

- `try?` remains acceptable in read-only cache/fallback paths, sleeps, regex/parser setup, and optional services.
- Primary user-save paths no longer have silent `try?` matches from the review scan.
- Full localization audit is still large: several visible strings remain hardcoded in recipe, voice, onboarding, settings/profile, friends, and add-related screens.
- Production social/auth still depends on Supabase/Google config and real device validation.
