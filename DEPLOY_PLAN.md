# Fitgram — план деплоя ветки `fix/deploy-blockers`

Составлен 2026-10-14. Что и зачем сделано — в [TODO.md](TODO.md); здесь только порядок выкладки.

Порядок важен: **воркер раньше миграций.** Миграция `20261012` сбрасывает все старые флаги Premium,
и вернуть их может только воркер с ключом `SUPABASE_SERVICE_ROLE_KEY`. Если перепутать — подписчики
не смогут постить, пока не появится воркер с ключом и они не перезапустят приложение.

Каждый шаг заканчивается проверкой. Не прошла — остановиться, шаги дальше не делать.

---

## Шаг 0. Решить до сборки (5 минут)

- [ ] **Обещания памяти Оли.** Памяти и обучения на реакциях в коде нет (реакции 👍/👎 на советах
      живут только пока открыт экран), но:
  - в приложении на экране «Porady od Oli» висят плашки «Pamięta kontekst» и «Uczy się z reakcji» —
    `Fitgram/Features/Coach/Components/OlaTipsLivingComponents.swift:91-92`;
  - на скриншоте `Marketing/App Store screenshots/05_Coach_Ola.jpg` — «remembers you»,
    «Remembers context», «Learns from reactions».

  Это тот же риск отказа по 2.3.1, что был с iCloud. Варианты: убрать плашки из кода и
  переснять скриншот 05, либо оставить и принять риск. Советую убрать.

## Шаг 1. Сборка на Mac (30–60 минут)

Swift-правки в ветке написаны без компиляции. Это главный неизвестный шаг.

```bash
git fetch && git checkout fix/deploy-blockers
make generate
make lint
make build
make test
```

Проверка:
- [ ] `make build` без ошибок.
- [ ] `make lint` чистый (в CI стоит `--strict`, предупреждения тоже ошибки).
- [ ] `make test` зелёный; отдельно смотреть `WeeklyDebriefTests`, `UsageMeterTests`, `TodayStateTests`.

Если что-то падает — прислать вывод, исправлю в ветке.

## Шаг 2. Мерж

- [ ] Открыть PR `fix/deploy-blockers` → по вашему обычному процессу (`develop`, затем `main`).
- [ ] Не включать `scripts/sideload.sh` — на Windows у него слетел флаг исполняемости, изменений в
      содержимом нет.

## Шаг 3. Воркер (10 минут)

```bash
cd worker
npx wrangler secret list
```

Проверить, что в списке есть: `SUPABASE_URL`, `GEMINI_API_KEY`, `ADMIN_TOKEN`,
`APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (синхронизация подписок),
`APPLE_SIWA_KEY_ID`, `APPLE_SIWA_PRIVATE_KEY` (отзыв токенов Apple при удалении аккаунта).

Без `APPLE_ISSUER_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY` сервер не узнает о подписках, и после
миграции Premium не получит никто. Добавить недостающие тем же `npx wrangler secret put ИМЯ`.

```bash
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY   # Supabase → Settings → API → service_role
npm ci && npx tsc --noEmit && npx vitest run
npx wrangler deploy
curl https://fitgram-app.bashyroov.workers.dev/healthz
```

Проверка:
- [ ] Тесты: 26 passed.
- [ ] `/healthz` отвечает `{"status":"ok"}`.

До миграции воркер просто пишет в лог `Premium mirror failed` — это ожидаемо.

Откат: `npx wrangler rollback`.

## Шаг 4. Supabase — миграции (10 минут)

Supabase → SQL Editor, по одной, строго в этом порядке:

1. `supabase/migrations/20261012_social_hardening.sql`
2. `supabase/migrations/20261013_post_text_rules.sql`
3. `supabase/migrations/20261014_moderation_handling.sql`

Проверка (вставить в SQL Editor):

```sql
select tgname from pg_trigger
where tgname in ('friendships_guard', 'public_profiles_guard_premium', 'posts_enforce_text');
-- ожидается 3 строки

select public.post_text_violation('Ale kurwa dobre', '');   -- profanity
select public.post_text_violation('Owsianka z bananem', ''); -- null
```

Откат, если что-то пошло не так:

```sql
drop trigger if exists friendships_guard on public.friendships;
drop trigger if exists public_profiles_guard_premium on public.public_profiles;
drop trigger if exists posts_enforce_text on public.posts;
-- затем заново выполнить supabase/migrations/20261009_posts_usernames.sql:
-- он вернёт прежнюю проверку Premium по is_premium (файл безопасно перезапускать)
```

## Шаг 5. Supabase — edge-функция (5 минут)

```bash
supabase functions deploy account --project-ref rrkvandbftozmwwfpfqi
```

Проверка на тестовом аккаунте с Premium:
- [ ] Опубликовать пост с фото → файл появился в Storage → `post-photos/<user_id>/`.
- [ ] Удалить аккаунт в приложении → папки `<user_id>` в `post-photos` больше нет, пользователя нет
      в Authentication → Users.

## Шаг 6. Разовые проверки и модерация (10 минут)

- [ ] Выполнить `supabase/scripts/check_forced_friendships.sql`. Пусто — ничего не делать.
- [ ] Настроить модерацию по [docs/MODERATION.md](docs/MODERATION.md): сохранённый запрос
      «Moderation queue» в SQL Editor + ежедневное напоминание. В Terms обещано 24 часа.

## Шаг 7. Сайт (5 минут)

Если Cloudflare Pages подключён к git — деплой произойдёт после мержа в production-ветку.
Иначе: CF Pages → проект → Upload assets → содержимое `landing/`.

Проверка:
- [ ] `https://fitgram.space/terms` и `/privacy` — «Last updated: October 12, 2026».
- [ ] В Terms есть раздел про жалобы и блокировки, в Privacy — «What other Fitgram users can see».

## Шаг 8. App Store Connect — вручную (15 минут)

- [ ] App Privacy: добавить **User ID, Name, Other User Content, Purchase History** (всё — App
      Functionality, linked to user, no tracking). Манифест в приложении уже совпадает.
- [ ] Скриншоты: если на шаге 0 решили убрать обещания памяти — заменить скриншот Оли.

```bash
bundle exec fastlane ios prepare_metadata
```

- [ ] В ASC в описаниях всех языков нет iCloud, Apple Watch и «помнит».

## Шаг 9. Билд в TestFlight (40 минут, в основном ожидание)

```bash
bundle exec fastlane ios beta
```

- Лейн сам поднимет номер билда (последний в TestFlight + 1) и запишет его в `project.yml` —
  закоммитить это изменение после загрузки.
- Профиль подписи пересоздастся: entitlement iCloud убран, это ожидаемо.

## Шаг 10. Проверка билда на устройстве (1 час)

Подписчик (sandbox):
- [ ] Покупка / restore → в `public_profiles` у пользователя заполнен `premium_until`.
- [ ] Пост публикуется; пост с матом или ссылкой — ошибка «контент отклонён».
- [ ] Kuchnia Oli: через несколько секунд сверху появляются 4–6 блюд от ИИ.
- [ ] Недельный отчёт Оли открыть дважды → в `/admin/dashboard` один запрос `weekly-debrief`.

Без подписки:
- [ ] Пост отклоняется с `premium_required`.

Друзья и модерация:
- [ ] Свою заявку в друзья принять нельзя; второй аккаунт принимает нормально.
- [ ] «…» на чужом посте → «Zgłoś post» → строка в `moderation_reports` с `reason` `post:<id> …`.

Общее:
- [ ] Вход через Apple, Google, email.
- [ ] Камера, штрихкод, голос.
- [ ] Удаление аккаунта (вместе с шагом 5).

## Шаг 11. Отправка на ревью

```bash
bundle exec fastlane ios release
```

Лейн заново отправит метаданные и скриншоты и подаст билд на ревью без автоматического релиза.
После одобрения — «Release This Version» в ASC вручную.

---

## Не блокирует, но лучше до релиза

- Пейволл: если StoreKit не вернул продукты, показываются зашитые `$4.99 / $44.99` и карточка
  «Plany testowe». Ревьюер может это увидеть. Работа на Mac, около часа.
- Кэш сканов в воркере (`wrangler kv namespace create scan-cache`).
- Остальное — разделы 4–6 в [TODO.md](TODO.md).
