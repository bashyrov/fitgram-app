# Mealgram Privacy Policy

_Last updated: 22 May 2026_

This is the privacy policy for **Mealgram**, the iOS app published by the developer reachable at `hello@mealgram.xyz`. By using Mealgram you accept the practices described below.

## What we collect

Mealgram collects the **minimum data needed to operate the app**:

| Category | Data | Why | Where it lives |
|---|---|---|---|
| Account | Name, email (only if you provide them), authenticated user ID | Sign in with Apple / Google / Email magic link | Supabase (EU region) |
| Meals & nutrition | Photos you scan, items you log manually, voice transcripts you confirm, weight entries, achievements, streaks | Core product functionality | On-device (SwiftData) + Supabase user row keyed by your ID |
| Coach memory | Free-text notes the AI Coach generates about your goals & preferences | Personalised insights | On-device (SwiftData) |
| Diagnostics | Crash reports, anonymous performance traces | Fix bugs | Sentry (EU region), no personal data attached |
| Subscription state | Whether your premium subscription is active | Feature gating | StoreKit / Apple; we don't see your payment details |

We **do not** collect: device IDs, advertising IDs, contacts, location, browsing history, biometric data, or anything for advertising or third-party marketing.

## How AI features work

When you take a photo of a meal, the image is sent (over HTTPS) to a Cloudflare Worker proxy that forwards it to Google Gemini for nutritional analysis. **The image is not retained** by the worker, by us, or by Gemini after the response returns. The same applies to recipe descriptions you ask Coach Ola to interpret.

If you use Apple Health import, the only field we read is **Body Mass** (your weight history). We never write back, and we never read activity, heart rate, sleep, or any other category.

## Where your data lives

- **On your device** — every meal, weight entry, achievement, photo thumbnail, recipe and coach insight is stored locally in SwiftData first.
- **Supabase (EU, GDPR-compliant)** — your account row + cloud copies of meals so you can restore on a fresh device. No third-party tools have access.
- **Apple servers** — only Sign in with Apple metadata and StoreKit subscription state.
- **iCloud** — premium-only optional sync; if enabled, the data uses your private iCloud container.

We **never sell** or share your data with advertisers, data brokers, or analytics SDKs that link to advertising profiles.

## Your rights (GDPR + CCPA)

You have the right to:

1. **Export** everything we have on you — Profile → Settings → "Download JSON / CSV / Full ZIP". The export contains every meal, weight, photo, recipe, achievement, and coach note keyed to your account.
2. **Delete** your account and all server-side data — Profile → Settings → "Delete account". This wipes your Supabase row, fires off the deletion across our backups within 30 days, and removes the app's local SwiftData. Irreversible.
3. **Object** to any specific processing — email `hello@mealgram.xyz` and we'll act within 30 days.

## Children

Mealgram is rated **17+** in the App Store because health/diet apps require user judgement. We don't knowingly collect data from children under 13. If you believe a child has created an account, email us and we'll delete the row immediately.

## Security

- All traffic over TLS 1.2+.
- Auth tokens stored in Keychain (hardware-encrypted on iOS).
- API keys never live in the app binary — Cloudflare Worker proxies all AI calls.
- Supabase rows enforce row-level security: you can only access your own data even if our keys leak.

## Changes to this policy

Material changes appear in the app's "What's New" sheet and at this URL with a fresh `Last updated` line. Continued use after a change means you accept the new terms.

## Contact

Mealgram Team  
Email: `hello@mealgram.xyz`  
Apple Developer Team ID: L55G3V9NJ3
