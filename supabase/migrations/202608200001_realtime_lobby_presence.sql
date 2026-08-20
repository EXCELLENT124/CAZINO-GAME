-- Keep the lobby accurate across phones. A device refreshes last_seen while
-- signed in; stale sessions are not presented as online.
create or replace view public.online_players with (security_invoker=true) as
select p.id,
       p.first_name,
       p.last_name,
       (pr.is_online and pr.last_seen > now() - interval '90 seconds') as is_online,
       pr.last_seen,
       w.balance,
       p.username
from public.profiles p
join public.player_presence pr on pr.user_id = p.id
join public.wallets w on w.user_id = p.id;

grant select on public.online_players to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'player_presence'
  ) then
    alter publication supabase_realtime add table public.player_presence;
  end if;
end $$;
