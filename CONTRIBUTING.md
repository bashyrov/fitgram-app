# Contributing to Mealgram

Short notes for anyone (human or AI) touching this codebase.

## Branch model

- `main` — production-ready. Never push directly.
- `develop` — integration branch. All feature work merges here.
- `feature/*` — one feature per branch. Open from `develop`, merge with
  `--no-ff` so the branch topology stays visible.

## Commit style

Conventional Commits.

```
feat(scope): one-line summary

Optional body — wrap at 72.
- Bullet what changed.
- Mention behaviour shifts, lint waivers, schema bumps.

Co-Authored-By: ...
```

Common scopes: `auth`, `data`, `networking`, `today`, `profile`,
`onboarding`, `scan`, `barcode`, `quick-db`, `voice`, `recipes`,
`progress`, `achievements`, `calibration`, `health`, `weight`,
`worker`, `docs`, `chore`.

After each milestone:

1. `make lint && make test` — both clean before commit.
2. Commit on the feature branch.
3. `git checkout develop && git merge --no-ff feature/<x>`
4. Update `CLAUDE.md` Current Status section.

## Code conventions

- All strings via `String(localized:)` (default language: Polish).
- All colours via `Tokens.Palette.*` referencing Asset Catalog entries.
- All sizing via `Tokens.Space.*`, radii via `Tokens.Radius.*`,
  type via `Tokens.Font.*`.
- No force unwraps in production code (`force_unwrapping: error` in
  swiftlint). Tests can use `XCTUnwrap`. Static-init helpers may use
  `fatalError("<reason>")` if the input is provably valid.
- No `print()` — use `Logger.<category>` (`os.log`).
- `async/await` everywhere; `@MainActor` for UI, actor isolation for
  shared state.
- SF Pro Rounded for all UI text.
- Light & airy design brief: warm cream backgrounds, sage primary,
  coral accent, generous whitespace, rounded everything, soft
  shadows. No harsh reds.

### Persistence

- Adding a new `@Model` type: register it in
  `MealgramSchemaV1.models`. SwiftData handles lightweight migration.
- Cross-context entities (one ModelContext per service call) need to
  re-fetch by id before mutating — see `RecipeRepository.delete` or
  `WeightService.delete` for the pattern.

### Side effects on save

`MealEntry` saves run through `MealSaving` (protocol). Anything that
needs to react to a save (streak update, achievement evaluation,
calibration sample count) lives in `ChainedMealSaver` inside
`RootView.swift` — one source of truth. Don't add `try? streakService...`
calls outside it.

### Accessibility

`A11yID` (in `Mealgram/DesignSystem/AccessibilityIdentifiers.swift`)
is the catalogue for UI-test reach. Add new identifiers there before
sprinkling them across views; never spell the string twice.

## Test conventions

- Unit tests live next to the type they exercise
  (`MealgramTests/<Type>Tests.swift`).
- Each test isolates its own SwiftData container via
  `PersistenceController.makeInMemory()`.
- Time-sensitive tests inject a `() -> Date` closure and a UTC
  `Calendar` so they don't wobble across timezones.
- Network-touching tests use `MockURLProtocol`
  (`MealgramTests/Support/MockURLProtocol.swift`).
- HealthKit / SFSpeech / AVCapture are protocol-fronted; tests stub
  the protocol rather than touching the real framework.

## Code review checklist

Before merging:

- [ ] `make lint` clean (swiftlint --strict)
- [ ] `make format-check` clean (no swift-format diffs)
- [ ] `make test` green
- [ ] New `@Model`? Added to `MealgramSchemaV1.models`.
- [ ] New side effect on `MealEntry` save? Routed through
      `ChainedMealSaver`.
- [ ] New tap target? Identifier added to `A11yID`.
- [ ] User-facing copy? Wrapped in `String(localized:)`.

## Worker (Cloudflare)

The TypeScript worker at `worker/` ships separately. From inside
`worker/`:

```bash
npm install
npx wrangler dev        # local
npx wrangler deploy     # production
```

Secrets:
- `SUPABASE_JWT_SECRET`
- `GEMINI_API_KEY`
- `UPSTASH_REDIS_URL` (optional)
- `UPSTASH_REDIS_TOKEN` (optional)

Use `wrangler secret put <NAME>` for production — never commit `.env`.

## What lives where

| Question | Where |
|----------|-------|
| Why this stack / decision X | `ARCHITECTURE.md` decision log |
| Current milestone status | `CLAUDE.md` Current Status |
| Required env vars | `.env.example` |
| Build commands | `Makefile` |
| Xcode config | `project.yml` (don't edit `.xcodeproj` directly) |
| Lint rules | `.swiftlint.yml`, `.swift-format` |

## Hot spots

These files change often; touch with care:

- `RootView.swift` — composition root; threading new dependencies
  ripples to `MealgramApp.swift` + `MainTabView.swift`.
- `MealgramSchemaV1.swift` — every `@Model` must register here.
- `TodayState.swift` — pulls from many services; new dependencies need
  defaults so it stays test-friendly.
- `A11yID` — shared by app + UI tests; rename via a global find/replace.

## Stopping points

Stop and ask the user for input only at the events documented in
`mealgram-master-prompt.md` Section "Когда ОСТАНАВЛИВАЕШЬСЯ": Bundle
ID / Apple Team Info, external service credentials, physical-device
testing, App Store submission assets, major architectural pivots.
Everything else, just keep building.
