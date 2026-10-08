-- Fix: friends, feed and search returned nothing.
--
-- RLS on public_profiles / activity_events calls can_view_profile(), which
-- reads profile_privacy and user_blocks rows owned by the OTHER user. Those
-- tables only expose rows to their owner, so under the caller's RLS the
-- check always failed and no foreign profile was ever visible.
--
-- The helpers now run as SECURITY DEFINER (pinned search_path). Because
-- they are also callable as RPC, each one answers only for the caller
-- (viewer must be auth.uid()), so nobody can probe other people's
-- friendships or blocks.

create or replace function public.are_friends(viewer uuid, owner uuid)
returns boolean language sql stable security definer set search_path = public as $$
    select viewer = auth.uid() and exists (
        select 1
        from public.friendships f, public.user_pair(viewer, owner) up
        where f.user_a = up.low and f.user_b = up.high and f.status = 'accepted'
    );
$$;

create or replace function public.is_blocked(viewer uuid, owner uuid)
returns boolean language sql stable security definer set search_path = public as $$
    select viewer = auth.uid() and exists (
        select 1 from public.user_blocks
        where (blocker = owner and blocked = viewer)
           or (blocker = viewer and blocked = owner)
    );
$$;

create or replace function public.can_view_profile(viewer uuid, owner uuid)
returns boolean language sql stable security definer set search_path = public as $$
    select case
        when viewer is distinct from auth.uid() then false
        when viewer = owner then true
        when public.is_blocked(viewer, owner) then false
        else exists (
            select 1 from public.profile_privacy pp
            where pp.user_id = owner
              and (
                  pp.visibility = 'public'
                  or (pp.visibility = 'friends' and public.are_friends(viewer, owner))
              )
        )
    end;
$$;

-- Same problem inside the activity_events policy, which read the owner's
-- profile_privacy toggles directly.
create or replace function public.can_view_event(viewer uuid, owner uuid, kind text)
returns boolean language sql stable security definer set search_path = public as $$
    select public.can_view_profile(viewer, owner)
        and exists (
            select 1 from public.profile_privacy pp
            where pp.user_id = owner and (
                (kind = 'streak.milestone' and pp.show_streak)
                or (kind = 'achievement.earned' and pp.show_achievements)
                or (kind = 'recipe.cooked' and pp.show_recipes)
                or (kind = 'challenge.won' and pp.show_achievements)
                or (kind = 'goal.hit' and pp.show_goal)
                or kind = 'user.joined'
            )
        );
$$;

drop policy if exists "activity_events_other_read" on public.activity_events;
create policy "activity_events_other_read" on public.activity_events
    for select using (public.can_view_event(auth.uid(), user_id, event_type));
