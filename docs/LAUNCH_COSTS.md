# Mealgram — Launch Costs Cheatsheet

Last updated: 2026-05-13. All prices verified at provider docs/dashboards on that date.

## TL;DR

| To do | One-time | Monthly | Notes |
|---|---|---|---|
| **Hit TestFlight** | ~500 zł | 0 zł | Apple Dev + domain |
| **First 100 users** | ~500 zł | ~15 USD | AI + free tiers |
| **1000 MAU** | ~500 zł | ~70 USD | Cloudflare + AI start to bite |
| **10 000 MAU** | ~500 zł | ~250-400 USD | Supabase Pro + AI scale |
| **50 000 MAU** | ~500 zł | ~1000-2000 USD | Real ops |

Apple Dev costs renew annually ($99). Everything else is provider pay-as-you-go.

---

## One-Time Costs

### Apple Developer Program — **REQUIRED**
- **$99 / year** (~400 zł)
- Without it: no TestFlight, no App Store, no Sign in with Apple capability, no HealthKit entitlement, no Push notifications, no App Groups (= widget broken)
- Buy: https://developer.apple.com/programs/
- Renews annually; missing payment = app pulled from store + capability revoke

### Domain `mealgram.pl`
- ~80 zł / year via OVH/nazwa.pl
- Needed for: Universal Links (replace `mealgram://friend/<id>` deep links with `https://mealgram.pl/u/<id>`), branded email (`hello@mealgram.pl`), web landing
- Optional for TestFlight, required for App Store submission (Apple wants a privacy URL)

### Polish JDG / sp. z o.o.
- ZUS: ~150 zł/mo (Ulga na start) for ~6 months, then ~1400 zł/mo
- Needed for: receiving payouts from Apple (RevenueCat → Apple → your IBAN)
- Apple holds money for ~45 days then transfers; minimum payout 150 zł
- Alternative: register as freelancer in another EU country (not recommended)

### Privacy policy + Terms
- DIY from Apple template: 0 zł, 4h work
- Iubenda generator: $27/year
- Lawyer-drafted: 1500-3000 zł single payment

**One-time total: 500-600 zł** (Apple + domain). JDG is a recurring monthly business cost separate from product infra.

---

## Recurring Provider Costs

### Infrastructure (all have generous free tiers)

| Provider | Free tier | Hits paid when | Paid tier |
|---|---|---|---|
| **Supabase** (DB + auth) | 500 MB DB, 1 GB storage, 50k MAU, 2 GB egress | DB > 500MB or MAU > 50k | $25/mo (Pro), 8 GB DB |
| **Cloudflare Workers** (AI proxy) | 100k req/day, 10ms CPU | > 100k req/day | $5/mo for 10M req |
| **Cloudflare R2** (meal photos) | 10 GB storage, 1M Class A ops | > 10 GB | $0.015 / GB / mo |
| **Upstash Redis** (worker cache) | 10k commands/day | > 10k cmd/day | $0.20 / 100k cmd |
| **Sentry** (error tracking) | 5k events/mo, 1 user | > 5k events | $26/mo (Team) |
| **PostHog** (product analytics) | 1M events/mo | > 1M events | $0.00005/event after |
| **RevenueCat** (subscriptions) | up to $2.5k MTR | > $2.5k MTR | 1% of revenue |

### AI APIs

| Provider | Use case | Pricing | Free tier |
|---|---|---|---|
| **Gemini 2.5 Flash** | Photo → food detection (M1.6) | $0.000075 per image, $0.30 / 1M output tokens | 1500 req/day via AI Studio |
| **Gemini 2.5 Pro** | Premium photo scans | $0.0001875 per image | Same daily quota |
| **Claude Sonnet 4.5** | Coach Ola weekly debriefs (M3.1) | $3 / 1M input + $15 / 1M output | None — pay from day 1 |
| **OpenAI Whisper** | Voice → text (if not on-device) | $0.006 / minute | None |

**Note:** Mealgram currently uses on-device SFSpeechRecognizer for voice (free). Skip Whisper unless you need non-iOS voice support.

---

## Per-User Cost Math

### Photo scans (Gemini Flash)
- 1 scan: $0.0001
- Average user: ~3 scans/day = 90/mo → **$0.009/mo per user**
- 1000 users: $9/mo
- 10 000 users: $90/mo

### Coach insights (Claude Sonnet 4.5)
- 1 weekly debrief: ~500 tokens in + 300 out = $0.0030 input + $0.0045 output ≈ **$0.0075**
- 4 debriefs/mo per active user = **$0.030/mo per user**
- Per-day insight (cheap rule-based today → swap to Claude later): ~200 tokens × 30 days = **$0.018/mo per user**
- Combined: **~$0.05/mo per active user** if every active user reads daily insights

### Infrastructure per user
- Storage (meal photos, ~5 per day, 200KB each): 30 MB/mo per user → R2 cost negligible (<$0.001/mo)
- DB rows: ~10 KB per user-day → 300 KB/mo per user → 1k users = 300 MB (Supabase free)
- Requests: 1k users × 10 API calls/day × 30 = 300k req/mo (well under Cloudflare free)

---

## Scenarios

### "Indie launch — just TestFlight" (you + 50 beta testers)
- One-time: **400 zł Apple** + ~80 zł domain
- Monthly: **0 zł** (everything on free tier including Gemini)
- AI: free tier (1500 req/day = 50 users × 30 scans, fine)
- **Burn rate: 0 zł/mo after one-time setup**

### "Public launch, first 1000 MAU"
- One-time: **400 zł Apple**
- Monthly:
  - Apple Dev amortised: $8/mo
  - AI: ~$50/mo (3k scans + 4k Coach insights)
  - Supabase: free
  - Cloudflare Workers: free (under 100k req/day at this scale)
  - Sentry: free
  - PostHog: free
- **Burn rate: ~$60/mo (~250 zł/mo)**

### "Growing — 10 000 MAU"
- Monthly:
  - Apple Dev amortised: $8
  - AI: ~$200-300 (scans + insights at scale)
  - Supabase Pro: $25
  - Cloudflare Workers: $5
  - Cloudflare R2 (300 GB photos): $5
  - Sentry: free still
  - PostHog: $50 (over event quota)
- **Burn rate: ~$300-400/mo (~1300-1700 zł/mo)**

### "Established — 50 000 MAU"
- AI: $700-1200
- Supabase: $100 (likely need Team plan)
- Cloudflare: $30
- Sentry: $26
- PostHog: $200
- **Burn rate: ~$1100-1600/mo (~4600-6700 zł/mo)**

---

## Revenue Math (PL pricing)

### Subscription tiers (from PaywallStepView mock)
- **Monthly:** 29 zł/mo
- **Yearly:** 199 zł/year (effectively 16.6 zł/mo, ~43% discount)
- **7-day free trial** on both

### Apple cut
- Year 1: **30%** for monthly + yearly subscriptions
- Year 2+ (yearly subscribers who stay): **15%**
- Small Business Program (< $1M/year): **15%** flat — qualifies until ~120k yearly subscribers

### RevenueCat cut
- 1% of revenue **after Apple's cut**

### Net per user (Small Business Program)
| Plan | Sticker | After Apple 15% | After RC 1% | Net |
|---|---|---|---|---|
| Monthly | 29 zł | 24.65 | 24.40 | **24.40 zł / mo** |
| Yearly (paid in full) | 199 zł | 169.15 | 167.46 | **167 zł / year = 13.92 zł / mo** |

### Break-even

Assuming 5% premium conversion (realistic for niche PL fitness/health):
- 1000 MAU → 50 premium users
- Mix: 70% monthly + 30% yearly
  - 35 × 24.40 = 854 zł/mo
  - 15 × 13.92 = 209 zł/mo
- **Total: ~1060 zł/mo revenue**
- Costs at 1000 MAU: ~250 zł/mo
- **Margin: ~810 zł/mo at 1000 MAU**

10 000 MAU at same conversion:
- 500 premium → ~10 600 zł/mo revenue
- Costs: ~1500 zł/mo
- **Margin: ~9000 zł/mo (~$2200) at 10k MAU**

50 000 MAU:
- 2500 premium → ~53 000 zł/mo revenue
- Costs: ~6000 zł/mo
- **Margin: ~47 000 zł/mo (~$11 500) at 50k MAU**

---

## Conservative First-Year Budget

### Pessimistic case (1000 MAU avg, 3% conversion)
- Revenue: 30 premium × ~20 zł avg net = 600 zł/mo = 7200 zł/year
- Costs: 250 zł/mo × 12 = 3000 zł/year + 400 zł Apple
- **Profit: ~3800 zł / year** (covers Apple + domain + JDG ZUS for 2 months)

### Realistic case (3000 MAU avg, 5% conversion)
- Revenue: 150 premium × ~20 zł avg net = 3000 zł/mo = 36 000 zł/year
- Costs: 600 zł/mo × 12 = 7200 zł/year + 400 zł
- **Profit: ~28 000 zł / year** (covers JDG ZUS + ~1k zł/mo developer salary)

### Optimistic case (10 000 MAU avg, 7% conversion)
- Revenue: 700 premium × ~20 zł = 14 000 zł/mo = 168 000 zł/year
- Costs: 1500 zł/mo × 12 = 18 000 zł/year
- **Profit: ~150 000 zł / year** — sustainable solo-developer business

---

## What's *Free* and Why That Matters

- **Apple's SFSpeechRecognizer** (Polish, on-device) — voice meal entry costs us nothing
- **Apple's Vision framework** (NSRecognizeTextRequest) — food-label OCR costs us nothing
- **Open Food Facts** — barcode database, no auth, no rate limit caps in practice (just respect their robots/ua)
- **CoreSpotlight** — Spotlight indexing costs nothing
- **Apple Health** — all read/write free with entitlement
- **WidgetKit** — widget extension costs nothing (storage shared via App Groups)
- **App Shortcuts / Siri intents** — free, no quotas
- **Local notifications** — free, no APNS dependency

This is why Mealgram can run with **zero per-user infrastructure cost** for everything except the photo→AI scan and the Coach LLM. Both of those have free tiers that cover the first 50-100 users comfortably.

---

## Pre-Launch Checklist (Order of Spending)

1. **Buy Apple Developer Program** — $99
   - Without this, none of the rest matters
2. **Buy domain `mealgram.pl`** — ~80 zł
   - Needed for App Store privacy URL + email
3. **Register JDG** — ZUS Ulga na start ~150 zł/mo first 6 months
   - Needed to receive Apple payouts
4. **Set up Supabase project** — free
   - Email magic link auth, friends backend
5. **Set up Cloudflare Worker** — free
   - Deploy the existing worker code
6. **Get Gemini API key from AI Studio** — free (1500 req/day quota)
7. **Get Anthropic API key for Claude** — pay-as-you-go, set $10 budget for first month
8. **Create RevenueCat account** — free
   - Set up products + entitlement
9. **App Store Connect** — included with Apple Dev
   - Create app listing, screenshots, subscription products
10. **Test in sandbox** — free
    - 7-day cycle through Sandbox Tester accounts
11. **Submit to TestFlight** — free
    - Beta with up to 10 000 external testers
12. **Submit to App Store** — free
    - Review takes 24-48h typically

**Total cost to launch: ~$99 + ~80 zł + first JDG month + maybe $10 AI prepay = ~600-700 zł**

---

## Risk Factors

- **Apple rejection on AI claims:** if marketing says "AI Coach" but offline mode shows rule-based generator, ASR can flag for "misleading description"
- **Gemini quota tightening:** Google has cut free tiers before; budget for $50-100/mo AI even at MVP scale as buffer
- **App Store Small Business threshold:** if you cross $1M/year revenue, Apple's cut jumps from 15% to 30% on new revenue
- **GDPR audits:** RODO compliance is mandatory in PL; export/delete flows already implemented, but legal review ~1500 zł single-payment is wise
- **Apple Sign In requirement:** if you offer Google/email, you MUST offer Apple Sign In (Apple guideline 4.8) — already implemented
- **App Store Review delays:** initial submission can take 1-2 weeks if metadata is incomplete; budget time, not money

---

## When to Worry About Money

- **MTR < 500 zł/mo:** keep AI on free tiers, defer Supabase Pro, run lean
- **MTR 500-3000 zł/mo:** infrastructure starts to matter, but still very lean; ~30% margin
- **MTR > 3000 zł/mo:** time to consider a part-time virtual assistant or contractor; AI is your main variable cost

Never spend more than 40% of MTR on infrastructure + AI combined. If you do, your unit economics are off.
