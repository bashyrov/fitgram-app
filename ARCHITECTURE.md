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
- **TCA** for flows with side effects + dependent state (Camera, Coach, Recipe parsing).
- **Repository** between SwiftData and feature modules.
- **Protocol-oriented services** for dependency injection and testability.
- **Coordinators** only when navigation cannot be expressed as `NavigationStack` + path.

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

## API Contracts

_Filled in during Milestone 1.6 (Worker integration)._
