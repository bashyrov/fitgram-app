# App Store Screenshots

## Current state

The 6 PNGs in `en-US/`, `pl/`, `uk/`, `ru/`, `es/` were captured before the 1.0.0 redesign. They show the right product but the splash + calibration step now look different. Apple accepts updated screenshots on a fresh submission — regenerate before pushing to App Store Review.

## Required sizes (Apple, 2026)

For iPhone, **6.9-inch display** is the only required size since iOS 18:

- **Resolution**: 1320 × 2868 pixels (portrait) — iPhone 16 Pro Max / 17 Pro Max
- **Minimum count**: 3 screenshots per locale
- **Maximum**: 10 per locale
- **Format**: PNG, sRGB

Optional: 6.5" (1242×2688) and 5.5" (1242×2208) for older devices. We skip these — Apple uses scaling.

## What to capture (priority order)

1. `1_iPhone_69_today.png` — Today screen with calorie ring, macros, streak header, meal timeline
2. `2_iPhone_69_scan.png` — Scan result screen with detected items
3. `3_iPhone_69_quickdb.png` — Quick Database search with results (shows 3000+ catalog)
4. `4_iPhone_69_progress.png` — Week tab with the 30-day calorie chart
5. `5_iPhone_69_profile.png` — Profile with achievements grid + heatmap
6. `6_iPhone_69_goal.png` — Goal completion screen / onboarding calibration

## Regeneration steps

```bash
# 1. Boot the right simulator (6.9-inch class)
xcrun simctl boot "iPhone 17 Pro Max"  # adjust to whatever's installed

# 2. Build & install
cd /Users/bashyrov/Projects/mealgram-workspace
xcodebuild -project Mealgram.xcodeproj -scheme Mealgram \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build

# 3. Launch with DebugBypass on (premium seeded user, 30 days of meals,
#    streaks, achievements). DebugBypass.bypassAuth is wired to true by
#    default in the current scheme — just open the app.
xcrun simctl launch booted app.mealgram.ios.bashyrov

# 4. Snap each screen via the simulator's screenshot CLI:
xcrun simctl io booted screenshot ~/Desktop/1_today.png
# (navigate within the app, repeat for each tab)
```

## Per-locale captures

Repeat the cycle with the simulator's system language set to each locale:

```bash
# Switch sim to Polish before launching the app
xcrun simctl spawn booted defaults write \
  "Apple Global Domain" AppleLanguages -array pl
xcrun simctl shutdown booted && xcrun simctl boot "iPhone 17 Pro Max"
```

Resulting PNGs go into `fastlane/screenshots/<locale>/` with the same numbered filenames so `fastlane deliver` picks them up.

## Then upload

```bash
bundle exec fastlane deliver
# or just metadata + screenshots
bundle exec fastlane deliver --skip_binary_upload true
```
