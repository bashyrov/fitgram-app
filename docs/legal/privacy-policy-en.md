# Mealgram Privacy Policy

**Version:** 1.0
**Effective date:** 2026-06-01
**Controller:** [YOUR_BUSINESS_NAME], NIP [NIP], REGON [REGON], address [ADDRESS], Poland
**Contact:** hello@mealgram.xyz

## 1. Who is the data controller

The controller of personal data collected through the Mealgram application (the "App") is [YOUR_BUSINESS_NAME] based in [CITY], Poland, NIP [NIP].

For privacy-related inquiries please contact us at **hello@mealgram.xyz**.

## 2. What data we collect

### 2.1. Account data
When you sign in with Apple ID, Google, or email we collect:
- external authentication provider identifier (e.g. Apple Sub)
- email address (if shared)
- first name (if shared — Apple/Google allow hiding it)

### 2.2. Health & nutrition data
When using the App you voluntarily provide:
- weight, height, date of birth, biological sex (for BMR/TDEE calculation)
- activity level, goal (lose / maintain / gain weight)
- dietary preferences (vegetarian, gluten-free, etc.)
- meals eaten — name, grams, calories, macronutrients
- meal photos (optional)
- voice recordings (optional, processed on-device)
- product barcode scans
- meal ratings (1–5 stars)
- meal tags
- text notes
- weight log entries
- water intake log

### 2.3. Technical data
We automatically collect:
- anonymous device identifier (managed by Apple)
- iOS version, device model (for crash reporting)
- language and time zone
- app error diagnostics (if you consent)
- anonymous usage analytics (if you consent)

### 2.4. Subscription data
When you buy a premium subscription:
- App Store transaction identifier
- subscription status (active / expired / trial)
- start and renewal dates

**We do not collect** payment card numbers — all payments are handled solely by Apple.

## 3. Why we process your data (purposes)

| Purpose | Legal basis (GDPR) |
|---|---|
| Service provision (login, save meals, statistics) | Art. 6(1)(b) — contract performance |
| Calorie and macro tracking | Art. 9(2)(a) — explicit consent (health data) |
| AI meal photo recognition | Art. 9(2)(a) — explicit consent |
| Push notifications | Art. 6(1)(a) — iOS system consent |
| Error diagnostics (Sentry) | Art. 6(1)(f) — legitimate interest |
| Anonymous analytics (PostHog) | Art. 6(1)(a) — consent |
| Subscription handling | Art. 6(1)(b) — contract |
| Legal obligations (e.g. refunds) | Art. 6(1)(c) |

## 4. Who we share data with (processors)

### 4.1. Apple Inc.
Apple ID login, in-app purchases, push notifications, iCloud sync (if enabled). Processed under Apple's privacy policy.

### 4.2. Supabase Inc. (USA + EU)
Authentication backend and account data storage. Servers in the European Union (Frankfurt). [Supabase Privacy](https://supabase.com/privacy).

### 4.3. Cloudflare Inc. (global)
Proxy for AI calls (Gemini, Claude). Data passes through Cloudflare Workers, cached for max 30 days. [Cloudflare Privacy](https://www.cloudflare.com/privacypolicy/).

### 4.4. Google LLC (Gemini API)
AI analysis of meal photos. Photos are sent without a user identifier and deleted immediately after processing. [Google AI Privacy](https://policies.google.com/privacy).

### 4.5. Anthropic PBC (Claude API)
Weekly AI coach "Ola" debriefs. We send anonymous summary statistics, no names or emails. [Anthropic Privacy](https://www.anthropic.com/legal/privacy).

### 4.6. RevenueCat Inc.
Premium subscription handling. We pass an anonymous user identifier. [RevenueCat Privacy](https://www.revenuecat.com/privacy).

### 4.7. Sentry GmbH (EU)
Crash diagnostics. Stack traces contain no personal data. [Sentry Privacy](https://sentry.io/privacy/).

### 4.8. PostHog Inc.
Anonymous product analytics. We don't use user IP and don't fingerprint. [PostHog Privacy](https://posthog.com/privacy).

### 4.9. Open Food Facts (Open Database License)
Public product database. Barcode scanning does not expose user identity.

**We do not sell** your data to third parties. We do not share it for advertising purposes.

## 5. Data transfers outside the EU

- Apple — USA, Standard Contractual Clauses (SCCs)
- Google — USA, SCCs + Data Processing Addendum
- Anthropic — USA, SCCs
- RevenueCat — USA, SCCs
- PostHog — USA, SCCs + EU-US Data Privacy Framework

All our processors comply with GDPR.

## 6. Data retention

| Category | Period |
|---|---|
| Account data | Until account deletion + 30 days |
| Meals, weight, statistics | Until account deletion + 30 days |
| Meal photos | Locally until deletion + 7 days; cloud sync (when enabled) 90 days |
| Error diagnostics | 90 days |
| Anonymous analytics | 365 days |
| Subscription data | 5 years from last transaction (accounting requirement) |

## 7. Your rights (GDPR)

You have the right to:

1. **Access your data** — JSON/CSV/ZIP export available in Profile → "Full bundle (ZIP)" or on request to hello@mealgram.xyz
2. **Rectify your data** — edit in-app or contact us
3. **Erasure** ("right to be forgotten") — Profile → "Delete account", or hello@mealgram.xyz. We process within 30 days
4. **Restrict processing** — write to hello@mealgram.xyz
5. **Object to processing** — write to hello@mealgram.xyz
6. **Data portability** — JSON export contains all data in a readable format
7. **Withdraw consent** at any time — without affecting processing before withdrawal
8. **Lodge a complaint** with the supervisory authority — Polish Personal Data Protection Office (UODO), ul. Stawki 2, 00-193 Warszawa, [uodo.gov.pl](https://uodo.gov.pl)

## 8. Profiling and automated decisions

The app uses algorithms ("AI Coach Ola") to generate personalized weekly summaries. These decisions:
- are informational / motivational
- have no legal effects
- do not significantly impact you

We do not use data for advertising profiling.

## 9. Security

We employ:
- TLS 1.3 encryption for connections
- iCloud Keychain encrypted storage for tokens
- restricted employee access to production databases
- regular security audits
- pseudonymization in diagnostic logs

In case of a data breach we will notify you within 72 hours as required by GDPR.

## 10. Children

The App **is not intended for users under 13 years of age**. We knowingly do not collect data of children. If we learn that an account belongs to a person under 13, we will delete it immediately.

Users aged 13–18 should obtain parent/guardian consent before creating an account.

## 11. Policy changes

We may update this policy. We will notify you of material changes:
- via in-app notice on next launch
- by email (if you left an address)
- with 30 days' notice before changes take effect

The current version is always available at [mealgram.xyz/privacy](https://mealgram.xyz/privacy) and in-app at Profile → Help / Privacy Policy.

## 12. Contact

Email: **hello@mealgram.xyz**
Postal address: [YOUR_ADDRESS]
Data Protection Officer (DPO): not appointed (sole proprietorship)

---

*Last updated: 2026-06-01*
