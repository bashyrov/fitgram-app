# Mealgram → App Store submission checklist

## ✅ Что я сделал автоматически

- **Privacy Manifest** (`Mealgram/Supporting/PrivacyInfo.xcprivacy`) — оформлен с задекларированными типами данных (email, photo, health, crash) и API-reasons (UserDefaults, FileTimestamp, SystemBootTime, DiskSpace).
- **fastlane Fastfile + Appfile** — три lane: `bump_build`, `beta` (TestFlight), `release` (submission).
- **Metadata на 5 локалей** (PL/EN/UK/RU/ES) в `fastlane/metadata/`: name, subtitle, description, keywords, promotional_text, release_notes + общие copyright, primary_category (`HEALTH_AND_FITNESS`), secondary (`FOOD_AND_DRINK`).
- **iCloud sync + App Groups + Push entitlements** ↗ enabled (commit `96f094b`).
- **5 языков локализации** UI + 150 фактов = ~7150 переведённых строк.
- **In-app language picker** (5 langs мгновенное переключение без рестарта).

## ⚠️ Что ОТ ТЕБЯ требуется до первого upload

### 1. App Icon (БЛОКЕР)

В [Mealgram/Resources/Assets.xcassets/AppIcon.appiconset/](Mealgram/Resources/Assets.xcassets/AppIcon.appiconset/) сейчас **только манифест без файлов**. Apple отклонит submission без иконки.

Что нужно:
- 1 PNG **1024×1024 без альфа-канала** (App Store icon)
- Универсальный icon — Xcode 14+ генерирует все остальные размеры автоматически

Простой путь: открой [icon.kitchen](https://icon.kitchen) (бесплатный онлайн-генератор), сделай иконку с буквой M на лайм-градиенте, скачай 1024×1024 PNG, перетащи в Xcode → AppIcon.appiconset.

### 2. Privacy Policy URL

Apple требует публичную страницу политики приватности. Mealgram собирает email, фото, health-data — без неё откажут.

Что нужно: страница `mealgram.pl/privacy` или `bashyrov.dev/mealgram-privacy` или GitHub Pages.
Шаблон уже подготовлен под факт что данные хранятся **только локально + iCloud** (no Mealgram servers). Если хочешь — попроси, сгенерирую markdown.

### 3. Support URL

Любая страница с контактом. Можно просто `mailto:hello@mealgram.pl` обёрнутая в `bashyrov.dev/mealgram-support`, или Notion-страничка, или Telegram-чат.

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
   - `mealgram.premium.monthly` (1 месяц, 16.60 zł)
   - `mealgram.premium.yearly` (1 год, 199 zł)
5. Запиши Product IDs — отдашь мне, я подключу к RevenueCat или прямой StoreKit 2
6. Установи RevenueCat SDK (опционально) → их dashboard сильно упрощает аналитику

## 🔥 Что я могу разблокировать после первого submission

Скажи и сделаю в один заход:
- Real photo scan через Cloudflare Worker + Gemini (нужны: Worker URL + Gemini API key)
- Email magic link auth через Supabase (нужны: Supabase URL + anon key)
- Google Sign In (нужен: Google OAuth Client ID)
- HealthKit write (записывать калории обратно в Apple Health)
- Live Activity push updates через APNs (для real-time обновления когда юзер вне приложения)
