# Mealgram — Pre-Launch Checklist

Concrete steps in execution order. Tick each box as you go. Total estimated time **2-3 weeks** solo developer.

## Phase 0: Money + accounts (1 day calendar, blocked by approvals)

- [ ] Buy [Apple Developer Program](https://developer.apple.com/programs/) ($99/year). **24-72h verification.**
- [ ] Register `mealgram.pl` (any PL registrar, ~80 zł)
- [ ] Set up business email `hello@mealgram.pl` (Google Workspace $6/mo or self-hosted)
- [ ] Register JDG / sp. z o.o. with PL tax office — needed for receiving Apple payouts
- [ ] Sign up [revenuecat.com](https://www.revenuecat.com) (free)
- [ ] Sign up [supabase.com](https://supabase.com) (free)
- [ ] Sign up [Cloudflare](https://www.cloudflare.com) (free, can use existing Workers account)
- [ ] Get Gemini API key from [Google AI Studio](https://aistudio.google.com) (free tier)
- [ ] Get Anthropic API key from [console.anthropic.com](https://console.anthropic.com) (pay-as-you-go, prepay $10)

## Phase 1: Assets (4 hours solo, longer if you commission designer)

- [ ] Install librsvg: `brew install librsvg`
- [ ] Run `./scripts/generate-app-icon.sh` to populate `AppIcon.appiconset`
- [ ] Run `./scripts/generate-launch-logo.sh` to populate `LaunchLogo.imageset`
- [ ] (Optional) Polish the icon in Figma — start from `docs/app-store/icon-source.svg`
- [ ] Capture 6 screenshots on iPhone 15 Pro Max simulator at 1290×2796:
  - [ ] Dziś tab — calorie ring full + streak + 2-3 meals visible
  - [ ] Add menu — confirmation dialog with 5 entry paths
  - [ ] Recipe detail — full nutrition + ingredients + cook timer
  - [ ] Coach Ola — weekly debrief with insight cards
  - [ ] Weight — chart with BMI band + 7-day average
  - [ ] Profile — stats grid + achievements grid + heatmap
- [ ] Capture same 6 on iPhone 11 Pro Max sim at 1242×2688
- [ ] (Optional) Capture App Preview video — 30 seconds, key flows

## Phase 2: App Store Connect setup (1 hour)

- [ ] [App Store Connect](https://appstoreconnect.apple.com) → My Apps → "+" → New App
  - Platform: iOS
  - Name: **Mealgram**
  - Primary Language: **Polish**
  - Bundle ID: **app.mealgram.ios**
  - SKU: **mealgram-ios-001**
- [ ] App Information:
  - Subtitle: **Polski licznik kalorii bez stresu**
  - Category: Health & Fitness / Lifestyle
  - Content Rights: **No** (we don't display third-party content beyond OFF attribution)
- [ ] Paste Privacy Policy URL: `https://mealgram.pl/privacy`
- [ ] Paste Support URL: `mailto:hello@mealgram.pl`
- [ ] Paste Marketing URL: `https://mealgram.pl`
- [ ] Localizations: add **English (US)** + **Ukrainian** + **Polish**
- [ ] For each language, paste from `docs/app-store/metadata-{pl,en,uk}.md`:
  - [ ] Name, Subtitle, Description, Keywords, Promotional text, What's New
- [ ] Upload screenshots for each device size × language
- [ ] Age rating questionnaire — answer "No" to everything → 4+

## Phase 3: App Privacy Details (15 min)

In ASC → your app → App Privacy:

- [ ] **Data Used to Track You:** None
- [ ] **Data Linked to You:**
  - [ ] User ID — for App Functionality
  - [ ] Email Address — for App Functionality
  - [ ] Health & Fitness — for App Functionality + Analytics
  - [ ] User Content (Other) — for App Functionality
- [ ] **Data Not Linked to You:**
  - [ ] Crash Data — Analytics
  - [ ] Performance Data — Analytics
  - [ ] Other Diagnostic Data — Analytics
  - [ ] Product Interaction — Analytics
- [ ] Save

## Phase 4: Subscriptions (45 min, requires #2 done)

- [ ] ASC → your app → Monetization → Subscriptions → Create Subscription Group:
  - Reference Name: **mealgram_premium**
- [ ] Inside group, create **mealgram_premium_monthly**:
  - Duration: 1 Month
  - Price: 29 PLN
  - Display name (PL): "Premium Miesięczna"
  - Display name (EN): "Premium Monthly"
  - Description: paste from metadata
  - Introductory Offer: Free Trial, 7 days
- [ ] Create **mealgram_premium_yearly**:
  - Duration: 1 Year
  - Price: 199 PLN
  - Display name (PL): "Premium Roczna"
  - Display name (EN): "Premium Annual"
  - Introductory Offer: Free Trial, 7 days
- [ ] App Information → Generate App-Specific Shared Secret → copy
- [ ] [revenuecat.com](https://app.revenuecat.com) → New Project "Mealgram"
- [ ] Apps → "+" → App Store → paste Bundle ID + Shared Secret
- [ ] Products → Import from App Store
- [ ] Entitlements → "+" → `premium` → attach both products
- [ ] Offerings → "default" → add packages `monthly` + `annual`
- [ ] Settings → API Keys → copy **Public iOS SDK Key**

## Phase 5: Wire credentials into code (30 min)

- [ ] In `project.yml` line 22 set `DEVELOPMENT_TEAM: "XXXXXXXXXX"` from Apple Developer membership
- [ ] Create `Config.xcconfig` (gitignored) at project root:
  ```
  REVENUECAT_API_KEY = appl_xxxxxxxxxx
  SUPABASE_URL = https://xxx.supabase.co
  SUPABASE_ANON_KEY = eyJxxx...
  WORKER_BASE_URL = https://mealgram-worker.your-account.workers.dev
  GEMINI_API_KEY = AIza...
  ANTHROPIC_API_KEY = sk-ant-...
  ```
- [ ] Add `Config.xcconfig` to `.gitignore`
- [ ] In `project.yml`, point each target's `baseConfig` at `Config.xcconfig`
- [ ] In `MealgramApp.init()` read keys via `Bundle.main.infoDictionary` or `AppConfig`
- [ ] Add RevenueCat SPM dependency in `project.yml`:
  ```yaml
  packages:
    RevenueCat:
      url: https://github.com/RevenueCat/purchases-ios-spm
      from: "5.0.0"
  targets:
    Mealgram:
      dependencies:
        - package: RevenueCat
  ```
- [ ] `make generate`
- [ ] Replace `MockSubscriptionService` instantiation with `RevenueCatSubscriptionService`
- [ ] In `RevenueCatSubscriptionService.swift` uncomment the SDK call blocks
- [ ] `make build` → verify no signing errors

## Phase 6: Capabilities + Entitlements (20 min)

- [ ] [developer.apple.com](https://developer.apple.com/account) → Identifiers → "+" → App IDs → App
  - Description: Mealgram
  - Bundle ID: **app.mealgram.ios** (explicit)
  - Capabilities enable: ✅ Sign In with Apple, ✅ HealthKit, ✅ Push Notifications, ✅ App Groups
- [ ] Create App ID for widget: **app.mealgram.ios.widget**
  - Capabilities: ✅ App Groups
- [ ] Identifiers → App Groups → "+" → `group.app.mealgram.shared`
- [ ] Attach the App Group to both bundle IDs
- [ ] In Xcode (after `make generate`): both targets → Signing & Capabilities → "+ Capability" → add App Groups → tick `group.app.mealgram.shared`

## Phase 7: Cloudflare Worker deploy (15 min, if M1.6 photo→AI wanted)

- [ ] Install wrangler: `npm install -g wrangler` then `wrangler login`
- [ ] In `worker/` directory: `cp wrangler.toml.example wrangler.toml` and fill in `name` + `account_id`
- [ ] Set secrets: `wrangler secret put GEMINI_API_KEY` (paste when prompted)
- [ ] Deploy: `wrangler deploy`
- [ ] Note the deployed URL → that's your `WORKER_BASE_URL` for `Config.xcconfig`

## Phase 8: Supabase deploy (30 min, if M1.1 email auth wanted)

- [ ] Create project at [supabase.com/dashboard](https://supabase.com/dashboard/projects)
- [ ] Settings → API → copy Project URL + anon public key into `Config.xcconfig`
- [ ] Authentication → Email Templates → customize magic link to PL
- [ ] Authentication → URL Configuration → Site URL: `mealgram://auth-callback`
- [ ] Authentication → Email → enable Magic Link, disable signup confirmations

## Phase 9: Sandbox test (1 hour)

- [ ] ASC → Users and Access → Sandbox Testers → "+"
  - Email: `mealgram-test+sandbox@gmail.com` (or any unused address)
  - Password: any strong
- [ ] On iPhone → Settings → App Store → Sandbox Account → sign in with the tester
- [ ] Build & run Mealgram on device via Xcode
- [ ] Go through onboarding to paywall step
- [ ] Buy monthly subscription with the sandbox account → should succeed, no charge
- [ ] Verify `customerInfo.entitlements["premium"].isActive == true` (check logs)
- [ ] Test "Restore Purchases" flow
- [ ] After 6 minutes (sandbox 1-month = 6 min), verify renewal
- [ ] Cancel in iPhone Settings → verify expiration after next "renewal" check

## Phase 10: Final QA pass on real device (2 hours)

Walk through every primary user flow:
- [ ] Onboarding complete → Today screen renders
- [ ] Add meal via photo → save → appears in timeline
- [ ] Add meal via barcode → Open Food Facts lookup works
- [ ] Add meal via Quick DB search → save
- [ ] Add meal via voice — multi-item ("jajka i tost") splits correctly
- [ ] Add meal via Quick DB → "Zeskanuj etykietę" → Vision OCR reads label
- [ ] Recipe creation → cook from library
- [ ] Recipe modifications → suggestions appear
- [ ] Weight entry → BMI shows → 7-day average updates
- [ ] Streak counter increments after meal save
- [ ] Coach Ola insight shows on Today after a few meals
- [ ] Weekly debrief sheet opens from Today
- [ ] Friends → add via QR → InMemory backend
- [ ] Achievements unlock after qualifying actions
- [ ] CSV / ZIP export downloads
- [ ] Delete account → confirmation → data wiped
- [ ] Premium gating works after subscription
- [ ] Restore purchases works after re-install

## Phase 11: TestFlight (1-2 days)

- [ ] In Xcode: Product → Scheme → Edit Scheme → Run: Release
- [ ] Product → Destination: Any iOS Device (arm64)
- [ ] Product → Archive
- [ ] Distribute App → App Store Connect → Upload
- [ ] ASC → TestFlight → wait for processing (~30 min)
- [ ] Test Information → fill out Beta App Description, Email, Marketing URL
- [ ] Internal Testing → add yourself + collaborators
- [ ] Verify TestFlight install on real device
- [ ] External Testing → create group "Beta" → invite 5-10 friends
- [ ] **Beta App Review** required first time → 24h typical
- [ ] After approval, send invite emails

## Phase 12: App Store submission (1-2 weeks review)

- [ ] ASC → App Store tab → "+" Version 1.0
- [ ] Fill all required fields if any missed earlier
- [ ] Build → choose the TestFlight build that passed Beta Review
- [ ] App Review Information:
  - Sign-In Required: **Yes** (Apple ID for testing)
  - Demo Account: provide a sandbox user
  - Notes: "AI features (photo→food, Coach Ola) use Google Gemini + Anthropic Claude via Cloudflare Worker proxy. No personal data sent."
- [ ] Version Release: Manually release (recommend for v1.0)
- [ ] **Submit for Review** → 24-48h typical, can be 7-14 days for first submission
- [ ] If rejected: read carefully, fix, resubmit. Common rejects:
  - Privacy policy doesn't mention all third-parties → fix `privacy-policy-pl.md`
  - Sign in with Apple not equivalent (Apple guideline 4.8) → already implemented
  - Subscription terms not clear → review price disclosure on paywall
  - Crash on review device → check Xcode crashlog
- [ ] Once approved: Click **Release This Version**

## Phase 13: Launch day (1 hour)

- [ ] App appears in App Store ~1-4 hours after release
- [ ] Post on r/poland, r/Polska, Reddit fitness subs (carefully — no spam)
- [ ] LinkedIn announcement
- [ ] Twitter/X with screenshots
- [ ] Cold-email Polish health bloggers
- [ ] Set up [ProductHunt](https://www.producthunt.com) submission for week 1
- [ ] Monitor Sentry / PostHog dashboards for crashes & onboarding drop-off

## Phase 14: Day-1 fires (24h)

- [ ] Watch Sentry for unexpected crashes
- [ ] Watch RevenueCat dashboard for first purchases
- [ ] Reply to App Store reviews within 24h
- [ ] Reply to email support within 24h

---

## Reference

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/) — apply once revenue confirmed, 15% commission instead of 30%
- [GDPR for app developers](https://gdpr.eu)
- [Polish UODO portal](https://uodo.gov.pl) — data protection authority

## Hot tips

- **Submit for review on Tuesday/Wednesday** — Mondays are backed up after weekend rejections, Fridays risk being held for the weekend
- **Don't include "AI" in keywords** — Apple is twitchy about AI marketing claims; describe what it does ("rozpoznawanie zdjęć"), not the tech
- **Make the description scannable** — bullet points > prose; first 3 lines visible without "more" tap
- **Localize the screenshots** — burn-in Polish UI text for PL screenshots, English UI text for EN store
- **Free trial conversion** — expect 5-15% trial-to-paid. Plan ad spend accordingly
