-- Demo people for one Fitgram account (TestFlight / screenshots):
--   Kasia, Michał, Ola — friends, with posts and likes;
--   Nina — sends you a friend request (tests the dot on "+");
--   Piotr — not a friend, open profile with public posts (tests search,
--   a stranger's profile and the "Dodaj do znajomych" button).
-- Run supabase/migrations/20261009_posts_usernames.sql first.
--
-- Before running:
--   1. Supabase → Authentication → Users → "Add user" five times, with
--      "Auto Confirm User" on and any password:
--        demo.kasia@fitgram.space   demo.michal@fitgram.space
--        demo.ola@fitgram.space     demo.piotr@fitgram.space
--        demo.nina@fitgram.space
--   2. Put YOUR account's email (as shown in Authentication → Users — with
--      Sign in with Apple it may be a ...@privaterelay.appleid.com address)
--      into my_email below.
-- Then paste the whole file into SQL Editor and run. Safe to re-run.
-- To remove later: delete the five demo.* users; cascades clean the rest.

do $$
declare
    my_email text := 'bashyroov@gmail.com';
    me uuid;
    friend record;
    pair_a uuid;
    pair_b uuid;
begin
    select id into me from auth.users where email = my_email;
    if me is null then
        raise exception 'No auth user with email %', my_email;
    end if;

    for friend in
        select * from (values
            ('demo.kasia@fitgram.space', 'kasia.nowak', 'Kasia Nowak', 'Biegam rano, jem dużo białka 🏃‍♀️',
             '21 dni z rzędu', 'Seria 21 dni', 'streak.milestone', 2,
             'Białko domknięte przed kolacją', 'Skyr rano, kurczak z ryżem na obiad. 21 dni serii!',
             '{"scope":"day","consumed_at":"2026-10-08T08:00:00Z","kcal":2050,"protein_g":168,"carbs_g":190,"fat_g":62,"goal_kcal":2100,"items":["Kurczak z ryżem","Skyr z malinami","Owsianka"],"meal_count":4}'::jsonb),
            ('demo.michal@fitgram.space', 'michal.w', 'Michał Wiśniewski', 'Siłownia 4x w tygodniu',
             'Cel białka 7 dni z rzędu', 'Tydzień białka', 'achievement.earned', 5,
             null, null, null),
            ('demo.ola@fitgram.space', 'ola.zielinska', 'Ola Zielińska', 'Gotuję wege i dzielę się przepisami 🥗',
             'Ugotowała: Curry z ciecierzycą', 'Curry z ciecierzycą', 'recipe.cooked', 9,
             'Curry z ciecierzycą — 540 kcal', 'Najlepszy obiad tygodnia, przepis w książce kucharskiej.',
             '{"scope":"meal","label":"Obiad","consumed_at":"2026-10-08T13:10:00Z","kcal":540,"protein_g":21,"carbs_g":72,"fat_g":17,"goal_kcal":1850,"items":["Ciecierzyca","Mleko kokosowe","Ryż basmati"],"meal_count":1}'::jsonb),
            ('demo.piotr@fitgram.space', 'piotr.k', 'Piotr Kowalczyk', 'Minus 6 kg od lutego',
             'Osiągnął cel wagi 82 kg', 'Cel wagi', 'goal.hit', 14,
             'Minus 6 kg od lutego', 'Bez cudów: deficyt 400 kcal, dużo białka i spacery po pracy.', null),
            ('demo.nina@fitgram.space', 'nina.lew', 'Nina Lewandowska', 'Nowa w Fitgram 👋',
             'Dołączyła do Fitgram', 'Nowa osoba', 'user.joined', 20,
             null, null, null)
        ) as t(email, username, display_name, bio, summary, title, event_type, hours_ago,
               post_title, post_body, post_macros)
    loop
        declare
            friend_id uuid;
        begin
            select id into friend_id from auth.users where email = friend.email;
            if friend_id is null then
                raise notice 'Skipping %: create this user in Authentication first', friend.email;
                continue;
            end if;

            insert into public.public_profiles (user_id, username, display_name, bio, is_premium)
            values (friend_id, friend.username, friend.display_name, friend.bio,
                    friend.username in ('kasia.nowak', 'ola.zielinska', 'piotr.k'))
            on conflict (user_id) do update
                set username = excluded.username,
                    display_name = excluded.display_name,
                    bio = excluded.bio,
                    is_premium = excluded.is_premium,
                    updated_at = now();

            insert into public.profile_privacy (
                user_id, visibility, show_streak, show_level, show_achievements,
                show_goal, show_weekly_stats, show_recipes, posts_visibility
            )
            values (
                friend_id, case when friend.username = 'piotr.k' then 'public' else 'friends' end,
                true, true, true, true, true, true,
                case when friend.username = 'piotr.k' then 'public' else 'friends' end
            )
            on conflict (user_id) do update
                set visibility = excluded.visibility, show_streak = true, show_level = true,
                    show_achievements = true, show_goal = true, show_weekly_stats = true,
                    show_recipes = true, posts_visibility = excluded.posts_visibility, updated_at = now();

            pair_a := least(me, friend_id);
            pair_b := greatest(me, friend_id);
            if friend.username = 'piotr.k' then
                delete from public.friendships where user_a = pair_a and user_b = pair_b;
            elsif friend.username = 'nina.lew' then
                insert into public.friendships (user_a, user_b, status, requested_by, accepted_at)
                values (pair_a, pair_b, 'pending', friend_id, null)
                on conflict (user_a, user_b) do update
                    set status = 'pending', requested_by = friend_id, accepted_at = null,
                        requested_at = now();
            else
                insert into public.friendships (user_a, user_b, status, requested_by, accepted_at)
                values (pair_a, pair_b, 'accepted', friend_id, now())
                on conflict (user_a, user_b) do update
                    set status = 'accepted', accepted_at = coalesce(public.friendships.accepted_at, now());
            end if;

            delete from public.posts where user_id = friend_id;
            if friend.post_title is not null then
                insert into public.posts (user_id, title, body, macros, local_day, created_at)
                values (
                    friend_id, friend.post_title, friend.post_body, friend.post_macros,
                    (now() - make_interval(hours => friend.hours_ago))::date,
                    now() - make_interval(hours => friend.hours_ago)
                );
            end if;

            delete from public.activity_events where user_id = friend_id;
            insert into public.activity_events (user_id, event_type, event_data, created_at)
            values (
                friend_id,
                friend.event_type,
                jsonb_build_object('title', friend.title, 'summary', friend.summary),
                now() - make_interval(hours => friend.hours_ago)
            );
        end;
    end loop;

    -- A couple of likes so the counters aren't all zero.
    insert into public.post_likes (post_id, user_id)
    select p.id, u.id
    from public.posts p
    join public.public_profiles author on author.user_id = p.user_id
    join auth.users u on u.email in ('demo.michal@fitgram.space', 'demo.kasia@fitgram.space')
    where author.username in ('kasia.nowak', 'ola.zielinska') and u.id <> p.user_id
    on conflict do nothing;
end $$;
