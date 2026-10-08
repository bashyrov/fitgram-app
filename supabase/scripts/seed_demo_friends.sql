-- Five demo friends for one Fitgram account (TestFlight / screenshots).
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
             '21 dni z rzędu', 'Seria 21 dni', 'streak.milestone', 2),
            ('demo.michal@fitgram.space', 'michal.w', 'Michał Wiśniewski', 'Siłownia 4x w tygodniu',
             'Cel białka 7 dni z rzędu', 'Tydzień białka', 'achievement.earned', 5),
            ('demo.ola@fitgram.space', 'ola.zielinska', 'Ola Zielińska', 'Gotuję wege i dzielę się przepisami 🥗',
             'Ugotowała: Curry z ciecierzycą', 'Curry z ciecierzycą', 'recipe.cooked', 9),
            ('demo.piotr@fitgram.space', 'piotr.k', 'Piotr Kowalczyk', 'Minus 6 kg od lutego',
             'Osiągnął cel wagi 82 kg', 'Cel wagi', 'goal.hit', 14),
            ('demo.nina@fitgram.space', 'nina.lew', 'Nina Lewandowska', 'Nowa w Fitgram 👋',
             'Dołączyła do Fitgram', 'Nowa osoba', 'user.joined', 20)
        ) as t(email, username, display_name, bio, summary, title, event_type, hours_ago)
    loop
        declare
            friend_id uuid;
        begin
            select id into friend_id from auth.users where email = friend.email;
            if friend_id is null then
                raise notice 'Skipping %: create this user in Authentication first', friend.email;
                continue;
            end if;

            insert into public.public_profiles (user_id, username, display_name, bio)
            values (friend_id, friend.username, friend.display_name, friend.bio)
            on conflict (user_id) do update
                set username = excluded.username,
                    display_name = excluded.display_name,
                    bio = excluded.bio,
                    updated_at = now();

            insert into public.profile_privacy (
                user_id, visibility, show_streak, show_level, show_achievements,
                show_goal, show_weekly_stats, show_recipes
            )
            values (friend_id, 'friends', true, true, true, true, true, true)
            on conflict (user_id) do update
                set visibility = 'friends', show_streak = true, show_level = true,
                    show_achievements = true, show_goal = true, show_weekly_stats = true,
                    show_recipes = true, updated_at = now();

            pair_a := least(me, friend_id);
            pair_b := greatest(me, friend_id);
            insert into public.friendships (user_a, user_b, status, requested_by, accepted_at)
            values (pair_a, pair_b, 'accepted', friend_id, now())
            on conflict (user_a, user_b) do update
                set status = 'accepted', accepted_at = coalesce(public.friendships.accepted_at, now());

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
end $$;
