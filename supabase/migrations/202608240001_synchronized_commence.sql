-- Let either participant commence an initialized match while keeping ordinary
-- state transitions turn-checked. The client stores dealing/continuation
-- coordination inside the existing JSON snapshot, so no exposed table is added.
create or replace function public.submit_game_state(
  game uuid,
  expected_version integer,
  next_state jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.game_sessions;
  new_version integer;
  commencement_only boolean;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;

  select * into g
  from public.game_sessions
  where id = game and status = 'active'
  for update;

  if not found or (select auth.uid()) not in (g.player_one, g.player_two) then
    raise exception 'Game unavailable';
  end if;
  if g.version <> expected_version then
    raise exception 'STALE_GAME_STATE';
  end if;

  commencement_only :=
    coalesce((g.state ->> 'commenced')::boolean, false) = false
    and coalesce((next_state ->> 'commenced')::boolean, false) = true
    and (next_state - 'commenced') = (g.state - 'commenced');

  if not commencement_only
     and g.state ->> 'current_player_id' <> (select auth.uid())::text then
    raise exception 'NOT_YOUR_TURN';
  end if;
  if coalesce((g.state ->> 'commenced')::boolean, false)
     and not coalesce((next_state ->> 'commenced')::boolean, false) then
    raise exception 'A commenced game cannot be reset';
  end if;
  if next_state ->> 'challenger_id' <> g.player_one::text
     or next_state ->> 'host_id' <> g.player_two::text then
    raise exception 'Players cannot be changed';
  end if;
  if next_state ->> 'current_player_id'
     not in (g.player_one::text, g.player_two::text) then
    raise exception 'Invalid next player';
  end if;

  new_version := g.version + 1;
  update public.game_sessions
  set state = next_state, version = new_version, updated_at = now()
  where id = game;
  insert into public.game_events(game_id, version, actor_id)
  values (game, new_version, (select auth.uid()));
  return new_version;
end;
$$;

revoke all on function public.submit_game_state(uuid, integer, jsonb)
  from public, anon;
grant execute on function public.submit_game_state(uuid, integer, jsonb)
  to authenticated;
