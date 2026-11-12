-- GoBoard step 27: admins can restore or remove a player's daily streak (Admin page -> Players -> Change streak).
-- Paste this into Supabase: SQL Editor -> New query -> Run. Safe to run more than once.

-- p_days 0 removes the streak. p_set_best also sets the best streak to p_days (it can lower it);
-- otherwise the best streak only goes up. Earned achievements stay. Returns null when done, otherwise why not.
create or replace function public.admin_set_streak(p_player uuid, p_days integer, p_set_best boolean, p_reason text, p_code text)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  problem text := public.admin_code_problem(p_code);
  old_streak integer;
  old_best integer;
begin
  if problem is not null then return problem; end if;
  if p_days is null or p_days < 0 or p_days > 10000 then return 'The streak must be between 0 and 10000 days'; end if;
  select streak, streak_best into old_streak, old_best from public.profiles where id = p_player;
  if old_streak is null then return 'That player wasn''t found'; end if;
  update public.profiles
    set streak = p_days,
        -- counted as played today (server's day), so it lasts the usual 7 days from now
        streak_day = case when p_days > 0 then (now() at time zone 'utc')::date end,
        streak_best = case when coalesce(p_set_best, false) then p_days else greatest(streak_best, p_days) end
    where id = p_player;
  perform public.log_admin('set_streak', p_player,
    old_streak || ' → ' || p_days
    || case when coalesce(p_set_best, false) then ' (best ' || old_best || ' → ' || p_days || ')' else '' end
    || coalesce(nullif(': ' || left(btrim(coalesce(p_reason, '')), 200), ': '), ''));
  return null;
end;
$$;
revoke all on function public.admin_set_streak(uuid, integer, boolean, text, text) from public, anon;
grant execute on function public.admin_set_streak(uuid, integer, boolean, text, text) to authenticated;

notify pgrst, 'reload schema';
select 'streak tool ready' as status;
