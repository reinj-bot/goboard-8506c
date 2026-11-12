-- GoBoard step 26: the streak only ends after 7 days in a row with no play (it used to end after 1).
-- Each day you play still adds one day. Paste this into Supabase: SQL Editor -> New query -> Run.
-- Safe to run more than once.

create or replace function public.record_activity(p_day date)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  me uuid := auth.uid();
  today date := public.checked_day(p_day);
  p public.profiles;
  new_streak integer;
begin
  if me is null then return 0; end if;
  select * into p from public.profiles where id = me for update;
  if p.streak_day is not null and p.streak_day >= today then return p.streak; end if;
  -- Up to 6 empty days in between keep the streak; 7 empty days end it (js/achievements.js shows the same).
  new_streak := case when p.streak_day >= today - 7 then p.streak + 1 else 1 end;
  update public.profiles
    set streak = new_streak, streak_best = greatest(streak_best, new_streak), streak_day = today
    where id = me;
  return new_streak;
end;
$$;
grant execute on function public.record_activity(date) to authenticated;

select 'streak now lasts 7 days' as status;
