# Fitgram — TODO перед отправкой в App Store

Обновлено: 2026-10-12. Источник — ревью готовности к деплою и фиксы пяти блокеров.
Правки лежат в ветке `fix/deploy-blockers` (запушена); ничего не задеплоено.

## 1. Выкатить фиксы блокеров (порядок важен)

- [ ] Просмотреть ветку `fix/deploy-blockers` и смёржить её (PR в `main` или через `develop`).
- [ ] Воркер: добавить секрет и задеплоить.
  `cd worker && npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY && npx wrangler deploy`
  Без этого шага после миграции подписчики не смогут постить.
- [ ] Supabase → SQL Editor: выполнить по очереди `supabase/migrations/20261012_social_hardening.sql`
      `supabase/migrations/20261013_post_text_rules.sql` и
      `supabase/migrations/20261014_moderation_handling.sql`.
- [ ] Задеплоить edge-функцию `account` (`supabase functions deploy account`).
- [ ] Проверить edge-функцию вручную: тестовый аккаунт → пост с фото → удалить аккаунт →
      файл в bucket `post-photos` исчез. Локально функция не запускалась.
- [ ] Задеплоить `landing/` (Cloudflare Pages), проверить `/terms` и `/privacy` — дата 12 октября 2026.
- [ ] `bundle exec fastlane ios prepare_metadata` — описания и release notes без iCloud / Apple Watch.
- [ ] Собрать новый билд (`bundle exec fastlane ios beta`) — новые тексты разрешений HealthKit.

## 2. Проверить после выкладки

- [ ] Подписчик: запустить приложение → в `public_profiles` появился `premium_until` → пост публикуется.
- [ ] Без подписки: пост отклоняется с `premium_required`.
- [ ] Заявка в друзья: отправитель не может принять её сам; получатель принимает нормально.
- [ ] Mac: `make generate && make build` — Swift-правки (жалоба на пост) написаны без компиляции:
      `PostViews.swift`, `FriendsState.swift`, `FriendsRootView.swift`, `FriendProfileView+PostsTab.swift`.
- [ ] Жалоба на пост: «…» на чужом посте → «Zgłoś post» → в `moderation_reports` появилась строка
      с `reason`, начинающимся на `post:<id>`.
- [ ] Пост с матом или ссылкой через прямой запрос к API отклоняется (`check constraint`).
- [ ] Kuchnia Oli (Pro): открыть экран → через несколько секунд сверху появляются 4–6 блюд от ИИ.
      Раньше запрос уходил без токена и воркер отвечал 401.
- [ ] Недельный отчёт Оли (Pro): открыть дважды за день → в панели `/admin/dashboard` один запрос
      `weekly-debrief`, а не два; цифры в плитках при этом обновляются.
- [ ] Правки кэша отчёта написаны без компиляции: `CoachService.swift`, `WeeklyDebrief.swift`,
      `CoachInsightCache.swift`, `CoachInsightGenerator.swift`, `WorkerCoachInsightGenerator.swift`;
      прогнать `WeeklyDebriefTests`.
- [ ] Mac: `make test` — 506 unit / 4 UI тестов (последний прогон был 28 сентября, до постов и юзернеймов).
- [ ] Секреты на живом воркере: `APPLE_SIWA_KEY_ID`, `APPLE_SIWA_PRIVATE_KEY`, `APPLE_ISSUER_ID`,
      `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `ADMIN_TOKEN`. Без SIWA-ключа отзыв токенов Apple
      при удалении аккаунта молча пропускается.
- [ ] Реальное устройство: вход через Apple / Google / email, покупка и restore в sandbox,
      камера, штрихкод, голос, удаление аккаунта.

## 3. Модерация и разовые проверки

- [ ] Настроить ежедневный просмотр жалоб по `docs/MODERATION.md` (сохранённый запрос в SQL Editor
      + напоминание). Обещание «24 часа» в Terms оставлено.
- [ ] Один раз после миграций запустить `supabase/scripts/check_forced_friendships.sql`.
      Пустой результат — навязанных дружб нет; иначе удалить строки вручную.

## 4. Стоит поправить до релиза (не блокеры)

- [ ] Пейволл: если StoreKit не вернул продукты, показывать ошибку, а не зашитые `$4.99` / `$44.99`
      и карточку «Plany testowe». Затрагивает `StoreKitSubscriptionService`, `UpgradeSheet`,
      `PaywallView`, `PaywallStepView` — делать на Mac, с проверкой экрана покупки.
- [ ] App Privacy в App Store Connect: добавить User ID, Name, Other User Content, Purchase History —
      манифест в приложении уже обновлён, ответы в ASC должны совпадать.
- [ ] Подключить кэш сканов: `npx wrangler kv namespace create scan-cache`, вписать id в `wrangler.toml`.
- [ ] App Store Server Notifications — чтобы сервер узнавал о возвратах без запуска приложения.

Сделано 2026-10-12 (ждёт выкладки из раздела 1):

- [x] Жалоба на конкретный пост (меню «…» на чужих постах).
- [x] Серверная проверка текста постов — `20261013_post_text_rules.sql`, те же правила, что в приложении.
- [x] `PrivacyInfo.xcprivacy`: добавлены User ID, имя, пользовательский контент, история покупок.
- [x] `worker/wrangler.toml`: `leafapi.cc` заменён на `https://api.anthropic.com`. Если Claude когда-нибудь
      включат (`AI_PROVIDER = "claude"`), нужен ключ самого Anthropic.

Снято:

- 8 строк без перевода — это осиротевшие ключи каталога, в коде они не используются.
- Убрать `is_premium` из `SocialProfileService.syncProfile` — не нужно: сервер поле игнорирует,
  а сам запрос заставляет базу пересчитать значок Premium.

- [ ] Память Оли: хранилище `CoachMemoryStore` есть, но в него никто не пишет — либо реализовать,
      либо убрать поле `memory` из запроса. В описаниях «помнит цели» уже заменено на «учитывает».
- [ ] Эндпоинты воркера `coach/daily-insight` и `coach/daily-plan` приложением не вызываются —
      удалить или оставить осознанно.

## 5. Мелочи

- [x] Устаревшие документы поправлены: `docs/PRE_LAUNCH_CHECKLIST.md`, `DEPLOY_READINESS.md`,
      `README.md`, `APP_STORE_SUBMISSION.md`.
- [ ] `web/*.md` и `docs/legal/*` — старые копии юридических текстов; удалить или синхронизировать с `landing/`.
- [x] Убраны entitlement iCloud/CloudKit, триггер пейволла `.iCloudSync` и Watch-таргет в `project.yml`
      (Swift-правки без компиляции — проверить сборкой и тестами `UsageMeterTests`).
- [ ] Ключи со статусом stale в `Localizable.xcstrings` не трогать: `L("…")` Xcode не извлекает,
      поэтому stale помечены и используемые строки.
- [ ] Apple Watch отложен: папка `FitgramWatch/` осталась в репозитории, но в проект не входит.
      Чтобы вернуть — восстановить таргет и схему `FitgramWatch` в `project.yml` из истории git
      и встроить его в таргет `Fitgram`.
- [ ] iCloud sync отложен: при возврате добавить entitlement обратно и включить `cloudKitDatabase`.

## 6. Мелкие замечания из ревью (низкий приоритет)

- [ ] Фото постов «только для друзей» лежат в публичном bucket и открываются по прямой ссылке
      любому, у кого она есть (в Privacy это теперь описано). Надёжнее — приватный bucket и signed URL.
- [ ] `reactions`: политика insert не проверяет, что получатель — друг и не заблокировал отправителя.
- [ ] Воркер, `/api/v1/user/initial-recommendations`: без авторизации, лимит 3 в день на IP и нет
      ограничения на размер тела запроса — добавить общий дневной потолок и лимит размера.
- [ ] Воркер, `auth.ts`: в ответе 401 наружу уходит текст ошибки проверки JWT — заменить на общий.
- [ ] Воркер, `admin.ts`: токен сравнивается обычным `===` — заменить на сравнение за постоянное время.
- [ ] Воркер, `subscriptions.ts`: транзакция привязывается к первому аккаунту, который её прислал
      (нет проверки `appAccountToken`).
- [ ] `StoreKitSubscriptionService.computeSnapshot`: `willRenew` считается по дате окончания,
      а не по статусу автопродления.

