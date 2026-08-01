# Mealgram → App Store submission checklist

## ✅ Что я сделал автоматически

- **Privacy Manifest** (`Mealgram/Supporting/PrivacyInfo.xcprivacy`) — оформлен с задекларированными типами данных (email, photo, health, crash) и API-reasons (UserDefaults, FileTimestamp, SystemBootTime, DiskSpace).
- **fastlane Fastfile + Appfile** — три lane: `bump_build`, `beta` (TestFlight), `release` (submission).
- **Metadata на 5 локалей** (PL/EN/UK/RU/ES) в `fastlane/metadata/`: name, subtitle, description, keywords, promotional_text, release_notes + общие copyright, primary_category (`HEALTH_AND_FITNESS`), secondary (`FOOD_AND_DRINK`).
- **Terms of Use / EULA для авто‑подписок**: публичная страница `https://mealgram.xyz/terms`, ссылка добавлена в App Store description всех 5 локалей и в App Review notes.
- **Public URL metadata**: `privacy_url.txt`, `support_url.txt`, `marketing_url.txt` добавлены для всех локалей fastlane.
- **iCloud sync + App Groups + Push entitlements** ↗ enabled (commit `96f094b`).
- **5 языков локализации** UI + 150 фактов = ~7150 переведённых строк.
- **In-app language picker** (5 langs мгновенное переключение без рестарта).

## ⚠️ Что ОТ ТЕБЯ требуется до первого upload

### 1. App Icon

В [Mealgram/Resources/Assets.xcassets/AppIcon.appiconset/](Mealgram/Resources/Assets.xcassets/AppIcon.appiconset/) уже есть `AppIcon-1024.png`.

Проверено: **1024×1024, без alpha** — подходит для App Store.

### 2. Public legal/support pages

Apple требует публичные страницы для privacy/support и рабочую Terms of Use / EULA ссылку для auto-renewable subscriptions.

Уже подготовлено:
- `https://mealgram.xyz/privacy`
- `https://mealgram.xyz/support`
- `https://mealgram.xyz/terms`

После деплоя `landing/` на хостинг запусти `fastlane ios prepare_metadata`, чтобы App Store metadata обновилась.

### 3. App Store metadata после rejection про EULA

Для текущего rejection:
1. задеплой `landing/terms.html` + redirect `/terms`
2. запусти `fastlane ios prepare_metadata`
3. в App Store Connect проверь, что description каждой локали содержит `https://mealgram.xyz/terms`
4. re-submit build for review

### 4. App Store Connect — создать app record

1. Зайди на [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → "+" → **New App**
2. Platform: **iOS**
3. Name: **Mealgram**
4. Primary Language: **Polish**
5. Bundle ID: выбери `app.mealgram.ios.bashyrov` (должен появиться раз paid team подключен)
6. SKU: `mealgram-ios-001` (любой уникальный)
7. User Access: **Full Access**

После создания — скопируй App ID (числа в URL) — пригодится потом.

### 5. App Store Connect API Key

1. Users and Access → **Integrations** → **App Store Connect API**
2. **Generate API Key**
3. Name: `mealgram-fastlane`, Role: **App Manager**
4. Скачай `.p8` файл (даётся один раз!) и положи в `~/Library/Keys/AuthKey_XXXXXXXXXX.p8`
5. Скопируй **Key ID** и **Issuer ID**
6. В корне репо создай `.env.fastlane`:
   ```
   APP_STORE_CONNECT_API_KEY_ID=XXXXXXXXXX
   APP_STORE_CONNECT_API_ISSUER_ID=00000000-...
   APP_STORE_CONNECT_API_KEY_PATH=~/Library/Keys/AuthKey_XXXXXXXXXX.p8
   ```
   (он в `.gitignore`)

### 6. Поставить fastlane

```bash
brew install fastlane
# или: sudo gem install fastlane -NV
```

### 7. Screenshots

Apple требует:
- **6.7"** (iPhone 15 Pro Max / 16 Pro Max): 1290 × 2796 px — **обязательно**
- 6.5" (iPhone 11 Pro Max / 14 Plus): 1242 × 2688 — рекомендуется

Минимум 3 скриншота на язык. Стандартный набор для Mealgram:
1. Today с большим калорийным кольцом и AI Coach
2. Scan result после фотоскана
3. Goal Tracking + 14-day chart
4. Friends leaderboard
5. Ola Tips → Ciekawostki

Скриншоты сделай в симуляторе iPhone 16 Pro Max (Xcode → Window → Devices → screenshots), сохрани в `fastlane/screenshots/{locale}/`.

### 8. Sandbox tester для StoreKit (если хочешь тестить покупки)

App Store Connect → Users and Access → **Sandbox** → **Testers** → "+" → создай sandbox Apple ID.

## 🚀 Когда всё готово — запуск

```bash
# Первый upload в TestFlight (тестовая раздача)
cd ~/Projects/mealgram-workspace
fastlane beta

# Когда тестеры одобрят и хочешь submit на App Store review
fastlane release
```

Apple review обычно 24-48 ч. На сообщения от Apple отвечать через App Store Connect Resolution Center.

## 📝 IAP (in-app purchases) — для платных подписок

Mealgram имеет paywall, но StoreKit пока в mock-режиме. Чтобы реально брать платежи:

1. App Store Connect → Apps → Mealgram → **Features** → **In-App Purchases** → "+"
2. Type: **Auto-Renewable Subscription**
3. Создай Subscription Group "Mealgram Premium"
4. Внутри группы создай продукты:
   - `mealgram_premium_monthly` (1 месяц, 16.60 zł)
   - `mealgram_premium_yearly` (1 год, 199 zł)
5. Включи 7-day free trial / introductory offer для обоих продуктов, если хочешь пробный период на оба плана.
6. Эти Product IDs уже подключены в StoreKit 2 в приложении — RevenueCat не обязателен для первого review.

## 🔥 Что я могу разблокировать после первого submission

Скажи и сделаю в один заход:
- Real photo scan через Cloudflare Worker + Gemini (нужны: Worker URL + Gemini API key)
- Email magic link auth через Supabase (нужны: Supabase URL + anon key)
- Google Sign In (нужен: Google OAuth Client ID)
- HealthKit write (записывать калории обратно в Apple Health)
- Live Activity push updates через APNs (для real-time обновления когда юзер вне приложения)
