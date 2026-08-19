-- Optimistic, turn-checked realtime match synchronization.
alter table public.game_sessions add column if not exists version integer not null default 0;
alter table public.game_sessions add column if not exists updated_at timestamptz not null default now();

create table if not exists public.game_events (
  id bigint generated always as identity primary key,
  game_id uuid not null references public.game_sessions(id) on delete cascade,
  version integer not null,
  actor_id uuid not null references auth.users(id),
  event_type text not null default 'state_transition',
  created_at timestamptz not null default now(),
  unique(game_id, version)
);
create index if not exists game_events_game_id_idx on public.game_events(game_id, version);
create index if not exists challenges_from_player_idx on public.challenges(from_player);
create index if not exists challenges_to_player_idx on public.challenges(to_player);
create index if not exists game_sessions_player_one_idx on public.game_sessions(player_one);
create index if not exists game_sessions_player_two_idx on public.game_sessions(player_two);
create index if not exists messages_room_created_idx on public.messages(room_id, created_at);

alter table public.game_events enable row level security;
create policy "participants read game events" on public.game_events for select to authenticated
using (exists(select 1 from public.game_sessions g where g.id=game_id and (select auth.uid()) in(g.player_one,g.player_two)));

create or replace function public.initialize_or_load_game(game uuid, initial_state jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare g public.game_sessions;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select * into g from public.game_sessions where id=game for update;
  if not found or (select auth.uid()) not in(g.player_one,g.player_two) then raise exception 'Game unavailable'; end if;
  if g.state='{}'::jsonb then
    if initial_state->>'challenger_id'<>g.player_one::text or initial_state->>'host_id'<>g.player_two::text
      then raise exception 'Invalid initial players'; end if;
    update public.game_sessions set state=initial_state,version=1,updated_at=now() where id=game
      returning * into g;
    insert into public.game_events(game_id,version,actor_id,event_type)
      values(game,1,(select auth.uid()),'initialized');
  end if;
  return jsonb_build_object('state',g.state,'version',g.version);
end $$;

create or replace function public.submit_game_state(game uuid, expected_version integer, next_state jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare g public.game_sessions; new_version integer;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select * into g from public.game_sessions where id=game and status='active' for update;
  if not found or (select auth.uid()) not in(g.player_one,g.player_two) then raise exception 'Game unavailable'; end if;
  if g.version<>expected_version then raise exception 'STALE_GAME_STATE'; end if;
  if g.state->>'current_player_id'<>(select auth.uid())::text then raise exception 'NOT_YOUR_TURN'; end if;
  if next_state->>'challenger_id'<>g.player_one::text or next_state->>'host_id'<>g.player_two::text
    then raise exception 'Players cannot be changed'; end if;
  if next_state->>'current_player_id' not in(g.player_one::text,g.player_two::text)
    then raise exception 'Invalid next player'; end if;
  new_version := g.version+1;
  update public.game_sessions set state=next_state,version=new_version,updated_at=now() where id=game;
  insert into public.game_events(game_id,version,actor_id) values(game,new_version,(select auth.uid()));
  return new_version;
end $$;

create or replace function public.game_for_challenge(challenge uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  select g.id into result from public.game_sessions g join public.challenges c on c.id=g.challenge_id
    where c.id=challenge and (select auth.uid()) in(c.from_player,c.to_player);
  if result is null then raise exception 'Game unavailable'; end if; return result;
end $$;

revoke all on function public.initialize_or_load_game(uuid,jsonb) from public,anon;
revoke all on function public.submit_game_state(uuid,integer,jsonb) from public,anon;
revoke all on function public.game_for_challenge(uuid) from public,anon;
grant execute on function public.initialize_or_load_game(uuid,jsonb) to authenticated;
grant execute on function public.submit_game_state(uuid,integer,jsonb) to authenticated;
grant execute on function public.game_for_challenge(uuid) to authenticated;
grant select on public.game_events to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.game_sessions;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.challenges;
exception when duplicate_object then null; end $$;
