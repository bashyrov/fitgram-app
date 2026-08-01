# Mealgram → Premium flip checklist

Current launch posture: `IS_PAYMENTS_ENABLED=false` → all features unlocked for every user. When the time comes to monetize, this is the entire sequence.

## ≈10-second flip (assuming all groundwork below is in place)

1. **App Store Connect**: in your app → "Subscriptions" → ensure both products are **Approved**:
   - `mealgram_premium_monthly` (auto-renewable, monthly)
   - `mealgram_premium_yearly` (auto-renewable, yearly)
2. **Edit one line** in [project.yml](project.yml#L148):
   ```yaml
   IS_PAYMENTS_ENABLED: "true"
   ```
3. **Bump version** + ship:
   ```bash
   make generate
   bundle exec fastlane beta   # uploads to TestFlight
   ```
4. Submit for App Store review. Done.

That's the entire user-facing change. Everything else listed below is the architecture that makes step 2 a one-line edit instead of a refactor.

---

## What happens automatically when the flag flips to `true`

| Component | Behavior |
|---|---|
| `MealgramApp.init` | Boot picks `StoreKitSubscriptionService()` instead of `MockSubscriptionService()`. See [MealgramApp.swift](Mealgram/App/MealgramApp.swift#L126) |
| `StoreKitSubscriptionService` | Fetches `mealgram_premium_monthly` + `mealgram_premium_yearly` via `Product.products(for:)` |
| User without active subscription | `snapshot.isPremium = false` → `EntitlementsStore.current = .free` |
| User with active subscription | StoreKit `Transaction.currentEntitlements` returns the row → `.premium` |
| Paywall sheets | `PaywallCoordinator.present(...)` now actually shows the sheet (no-op'd previously). See [PaywallCoordinator.swift:17](Mealgram/Core/Services/Subscriptions/PaywallCoordinator.swift#L17) |
| Free tier caps activate | `Entitlements.free` caps are read by feature UIs (Favorites, Recipes, Friends, Goals, History, Export) |

## How user data is protected on the flip

**Nothing is deleted.** This was an explicit requirement and the architecture guarantees it:

1. The `EntitlementsStore.onDowngradeFreeTier` callback is **empty** — see [MealgramApp.swift:204](Mealgram/App/MealgramApp.swift#L204). Previously it called `FavoritesService.trimToCap` which deleted excess rows; that destructive method has been removed entirely.
2. Soft caps apply only to **display**, not storage:
   - [FavoritesListView.swift](Mealgram/Features/Favorites/FavoritesListView.swift) keeps the full collection in `favorites`, slices into `visibleFavorites` at render time. Hidden rows are surfaced as a "+N ukrytych — Premium odblokuje" upsell card. Re-subscribing instantly re-reveals them.
3. Recipes / friends / custom goals follow the same pattern (TBD per surface — currently the **add** action raises paywall when count ≥ cap; reads stay unbounded).

## Premium products in App Store Connect

Both products must exist before the flip. StoreKit ID = exact constant from the iOS code:

| Product ID | Type | Price (suggested) | Trial |
|---|---|---|---|
| `mealgram_premium_monthly` | Auto-Renewable Subscription | 29 zł / 6.99 USD / 6.99 EUR | 7 days |
| `mealgram_premium_yearly` | Auto-Renewable Subscription | 199 zł / 39.99 USD / 39.99 EUR | 7 days |

Both share a single subscription group called `Mealgram Premium`. Localized display names + descriptions live in App Store Connect — fastlane doesn't push these (they're set in the iOS app via `Product.displayName` / `displayPrice`).

## What's gated behind premium (current spec)

Source of truth: [FreeTierLimits.swift](Mealgram/Core/Services/Subscriptions/FreeTierLimits.swift). All numbers are tunable in one file.

**Per-week quotas** (rolls over Monday 00:00):
- Photo scans: **5 / week**
- Barcode scans: **5 / week**
- Voice entries: **5 / week**
- AI Coach weekly debriefs: **1 / week**

**Soft display caps** (data preserved):
- Custom goals active: **1**
- Saved recipes: **5**
- Friends: **3**
- Favorites ("Moje przepisy"): **5**

**Other**:
- History charts limited to last **30 days** (older data readable, charts truncated)
- Export formats: free → JSON only; premium → JSON + CSV + ZIP
- Theme picker: premium-only
- iCloud sync: premium-only

## Required before flip (one-time setup)

- [ ] Apple Developer Program enrollment active (current Team ID: `L55G3V9NJ3` ✅)
- [ ] App.mealgram.ios.bashyrov approved & live on App Store at v1.0.0 free tier first
- [ ] Bank account + tax forms completed in App Store Connect → "Agreements, Tax, and Banking"
- [ ] Subscription Group `Mealgram Premium` created in App Store Connect
- [ ] Both IAP products created + reviewed + approved
- [ ] Subscription review screen filled in (Apple reviews subscriptions separately)
- [ ] Sandbox tester account created for local testing before flip
- [ ] StoreKit configuration file (`Mealgram.storekit`) — optional but useful for local IAP testing

## Verification path after the flip

After shipping the flipped build:

1. Install via TestFlight on a device signed into a **sandbox** Apple ID
2. Force the user to free tier (delete and reinstall, or sign in fresh)
3. Open Favorites — should see free cap (5) honored, "+N ukrytych" upsell visible if user previously had more
4. Tap "+" past cap → paywall sheet appears with both plans
5. Purchase monthly → 30-day expiration, `isPremium=true` everywhere
6. Restart app → entitlement persists via `Transaction.currentEntitlements`
7. Tap "Restore Purchases" → idempotent restore works
8. Cancel sandbox subscription → next refresh flips back to free; hidden rows reappear next subscribe

## Reverse flip (premium → free)

`IS_PAYMENTS_ENABLED=false` again → MockSubscriptionService returns `premium-mock` → everything unlocks. **No data lost** — same architecture both directions.

## Step-by-step: App Store Connect setup

Order matters — Apple checks each upstream piece before letting you create the next.

### 1. Banking + Tax (one-time, ~20 min)

**https://appstoreconnect.apple.com** → **Agreements, Tax, and Banking**

- Sign the **Paid Apps Agreement**
- Add a **bank account** (IBAN — your personal Polish account works as a physical person)
- Fill **Tax Information**:
  - W-8BEN (online form, takes 5 min) — confirms you're a non-US tax resident
  - Polish PESEL or NIP

Wait ~24h until "Active" status before continuing.

### 2. Subscription Group (one-time)

App Store Connect → your app → **Subscriptions** → **+ Subscription Group**

- Reference name: `Mealgram Premium`
- App Store Name (per locale): `Mealgram Premium`

### 3. Monthly product

Inside the group → **+ Subscription**

| Field | Value |
|---|---|
| Reference Name | `Premium Monthly` |
| Product ID | `mealgram_premium_monthly` (must match code exactly) |
| Subscription Duration | 1 Month |
| Cleared for Sale | Yes |
| Pricing | Tier of your choice (≈ 6.99 USD = 29 zł = 6.99 EUR) |

**Subscription Localizations** — add at least English:
- Display Name: `Premium Monthly`
- Description: `Unlimited AI scans, full Coach Ola, complete history, premium themes.`

**Introductory Offer** → **Free Trial** → **7 Days** → **Eligibility: New Subscribers**

### 4. Yearly product

Same process. Differences:

| Field | Value |
|---|---|
| Reference Name | `Premium Yearly` |
| Product ID | `mealgram_premium_yearly` |
| Subscription Duration | 1 Year |
| Pricing | ≈ 39.99 USD = 199 zł |

7-day free trial same as monthly.

### 5. Subscription Review Screen (per product)

Each product page → **App Review Information**:

- **Screenshot** (1284×2778) — take a screenshot of the paywall on iPhone simulator
- **Review Notes** (1-2 sentences):
  > "Premium is offered to users when they hit a free-tier limit (favorites cap, photo scan quota, etc.). Pricing and auto-renewal terms are disclosed on the paywall before purchase. Restore button available in the same sheet."

Apple **reviews subscriptions separately** from the app. Submit them with the next app build.

### 6. Sandbox Tester (one-time)

Settings → **Users and Access** → **Sandbox Testers** → **+**

- Email: `sandbox@mealgram.xyz` (or a fresh Apple ID — doesn't need to be real)
- Password, name, country (Poland)

On your iPhone: Settings → App Store → Sandbox Account → sign in with this tester. Now in-app purchases run through sandbox StoreKit (no real money).

### 7. Local testing without App Store Connect

`Mealgram/Supporting/Mealgram.storekit` is included in the scheme — when running from Xcode in Debug, the paywall uses **fake products from that file** instead of hitting App Store Connect. You can buy, restore, cancel without wiring anything in App Store Connect.

To flip between local fake products and real ones: Xcode → Edit Scheme → Run → Options → "StoreKit Configuration" → set to `Mealgram.storekit` (fake) or `None` (real App Store / Sandbox).

## Files involved

- `Mealgram/Core/Services/AppConfig.swift` — reads `IS_PAYMENTS_ENABLED` from Info.plist
- `Mealgram/Core/Services/Subscriptions/SubscriptionService.swift` — protocol + Mock implementation
- `Mealgram/Core/Services/Subscriptions/StoreKitSubscriptionService.swift` — real StoreKit2 backed service
- `Mealgram/Core/Services/Subscriptions/Entitlements.swift` — entitlements snapshot + free/premium factories
- `Mealgram/Core/Services/Subscriptions/FreeTierLimits.swift` — single-file tuning of caps
- `Mealgram/Core/Services/Subscriptions/PaywallCoordinator.swift` — central "raise upgrade sheet" dispatcher
- `Mealgram/Core/Services/Subscriptions/UsageMeter.swift` — per-week quota tracking
- `Mealgram/Features/Subscriptions/UpgradeSheet.swift` — the actual paywall UI
- `Mealgram/App/MealgramApp.swift` — composition root, swaps services on the flag
- `Mealgram/Features/Favorites/FavoritesListView.swift` — reference implementation of soft-cap display
