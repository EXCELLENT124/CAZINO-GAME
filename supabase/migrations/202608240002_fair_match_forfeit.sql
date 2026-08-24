-- The lobby view returns only players with a fresh online heartbeat. Keeping
-- wallets out of this invoker view also preserves private wallet RLS.
create or replace view public.online_players with (security_invoker = true) as
select p.id,
       p.first_name,
       p.last_name,
       true as is_online,
       pr.last_seen,
       0::integer as balance,
       p.username
from public.profiles p
join public.player_presence pr on pr.user_id = p.id
where pr.is_online = true
  and pr.last_seen > now() - interval '90 seconds';

grant select on public.online_players to authenticated;

-- Atomically settle an active match when one participant explicitly forfeits.
create or replace function public.forfeit_game(game uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.game_sessions;
  quitter uuid := (select auth.uid());
  winner uuid;
begin
  if quitter is null then
    raise exception 'Authentication required';
  end if;

  select * into g
  from public.game_sessions
  where id = game
  for update;

  if not found or quitter not in (g.player_one, g.player_two) then
    raise exception 'Game unavailable';
  end if;
  if g.status <> 'active' then
    raise exception 'Game is already complete';
  end if;

  winner := case when quitter = g.player_one then g.player_two else g.player_one end;

  update public.wallets
  set balance = balance + g.pot, updated_at = now()
  where user_id = winner;

  insert into public.wallet_ledger(user_id, amount, reason, reference_id)
  values (winner, g.pot, 'forfeit_win', g.id);

  update public.game_sessions
  set status = 'finished',
      winner_id = winner,
      finished_at = now(),
      version = version + 1,
      updated_at = now(),
      state = jsonb_set(
                jsonb_set(
                  jsonb_set(state, '{phase}', '"finished"'::jsonb, true),
                  '{winner_id}', to_jsonb(winner::text), true),
                '{forfeited_by_id}', to_jsonb(quitter::text), true)
  where id = g.id;

  update public.challenges
  set status = 'cancelled'
  where id = g.challenge_id;

  return winner;
end;
$$;

revoke all on function public.forfeit_game(uuid) from public, anon;
grant execute on function public.forfeit_game(uuid) to authenticated;
