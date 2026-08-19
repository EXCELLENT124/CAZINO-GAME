-- CAZINO online foundation. Virtual coins have no cash value and cannot be purchased or withdrawn.
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default 'Player', last_name text not null default '',
  avatar_url text, created_at timestamptz not null default now()
);
create table public.private_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone text, id_number text, date_of_birth date, address_line_1 text,
  address_line_2 text, city text, province text, postal_code text, country text,
  updated_at timestamptz not null default now()
);
create table public.fica_documents (
  id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  document_type text not null, file_name text not null, storage_path text,
  status text not null default 'staged' check (status in ('staged','pending','verified','rejected')),
  created_at timestamptz not null default now()
);
create table public.player_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_online boolean not null default false, last_seen timestamptz not null default now()
);
create table public.wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance integer not null default 0 check (balance >= 0), updated_at timestamptz not null default now()
);
create table public.wallet_ledger (
  id bigint generated always as identity primary key, user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null check (amount <> 0), reason text not null,
  reference_id uuid, created_at timestamptz not null default now()
);
create table public.daily_coin_claims (
  user_id uuid not null references auth.users(id) on delete cascade,
  claim_date date not null default (now() at time zone 'utc')::date,
  amount integer not null default 500 check (amount = 500),
  primary key(user_id, claim_date)
);
create table public.friend_requests (
  id uuid primary key default gen_random_uuid(), from_user uuid not null references auth.users(id) on delete cascade,
  to_user uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(), check(from_user <> to_user), unique(from_user,to_user)
);
create table public.friendships (
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(), check(user_a < user_b), primary key(user_a,user_b)
);
create table public.challenges (
  id uuid primary key default gen_random_uuid(), from_player uuid not null references auth.users(id) on delete cascade,
  to_player uuid not null references auth.users(id) on delete cascade,
  stake integer not null check(stake in (100,150,200,250,300,350,400,500)),
  status text not null default 'pending' check(status in ('pending','accepted','declined','cancelled','expired')),
  created_at timestamptz not null default now(), check(from_player <> to_player)
);
create table public.game_sessions (
  id uuid primary key default gen_random_uuid(), challenge_id uuid unique references public.challenges(id),
  player_one uuid not null references auth.users(id), player_two uuid not null references auth.users(id),
  stake integer not null, pot integer not null, status text not null default 'active' check(status in ('active','finished','cancelled')),
  winner_id uuid references auth.users(id), state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), finished_at timestamptz
);
create table public.messages (
  id uuid primary key default gen_random_uuid(), room_id text not null,
  sender_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text not null check(length(body) between 1 and 1000), created_at timestamptz not null default now()
);

create or replace function public.new_cazino_user() returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.profiles(id,first_name,last_name) values(new.id,coalesce(new.raw_user_meta_data->>'first_name','Player'),coalesce(new.raw_user_meta_data->>'last_name',''));
  insert into public.private_profiles(user_id) values(new.id);
  insert into public.player_presence(user_id) values(new.id);
  insert into public.wallets(user_id,balance) values(new.id,0);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.new_cazino_user();

create or replace function public.claim_daily_coins() returns integer language plpgsql security definer set search_path='' as $$
declare inserted_count int; result int;
begin
  insert into public.daily_coin_claims(user_id) values(auth.uid()) on conflict do nothing;
  get diagnostics inserted_count = row_count;
  if inserted_count = 1 then
    update public.wallets set balance=balance+500,updated_at=now() where user_id=auth.uid();
    insert into public.wallet_ledger(user_id,amount,reason) values(auth.uid(),500,'daily_reward');
  end if;
  select balance into result from public.wallets where user_id=auth.uid(); return result;
end $$;

create or replace function public.set_player_presence(online boolean) returns void language sql security definer set search_path='' as $$
  update public.player_presence set is_online=online,last_seen=now() where user_id=auth.uid();
$$;
create or replace function public.create_challenge(opponent_id uuid, coin_stake integer) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
  if opponent_id=auth.uid() or coin_stake not in (100,150,200,250,300,350,400,500) then raise exception 'Invalid challenge'; end if;
  if not exists(select 1 from public.wallets where user_id=auth.uid() and balance>=coin_stake) then raise exception 'Insufficient coins'; end if;
  insert into public.challenges(from_player,to_player,stake) values(auth.uid(),opponent_id,coin_stake) returning id into result; return result;
end $$;
create or replace function public.accept_challenge(challenge uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare c public.challenges; game uuid; p uuid; low_id uuid; high_id uuid;
begin
  select * into c from public.challenges where id=challenge and to_player=auth.uid() and status='pending' for update;
  if not found then raise exception 'Challenge unavailable'; end if;
  perform 1 from public.wallets where user_id in(c.from_player,c.to_player) order by user_id for update;
  if (select count(*) from public.wallets where user_id in(c.from_player,c.to_player) and balance>=c.stake)<>2 then raise exception 'A player has insufficient coins'; end if;
  update public.wallets set balance=balance-c.stake,updated_at=now() where user_id in(c.from_player,c.to_player);
  insert into public.game_sessions(challenge_id,player_one,player_two,stake,pot) values(c.id,c.from_player,c.to_player,c.stake,c.stake*2) returning id into game;
  insert into public.wallet_ledger(user_id,amount,reason,reference_id) values(c.from_player,-c.stake,'wager_escrow',game),(c.to_player,-c.stake,'wager_escrow',game);
  update public.challenges set status='accepted' where id=c.id;
  return game;
end $$;
-- Settlement is deliberately service-role only until the Dart engine is mirrored by an authoritative server validator.
create or replace function public.settle_game_authoritative(game uuid, winner uuid) returns void language plpgsql security definer set search_path='' as $$
declare g public.game_sessions;
begin
  select * into g from public.game_sessions where id=game and status='active' for update;
  if winner not in(g.player_one,g.player_two) then raise exception 'Invalid winner'; end if;
  update public.wallets set balance=balance+g.pot,updated_at=now() where user_id=winner;
  insert into public.wallet_ledger(user_id,amount,reason,reference_id) values(winner,g.pot,'wager_win',game);
  update public.game_sessions set status='finished',winner_id=winner,finished_at=now() where id=game;
end $$;
revoke all on function public.settle_game_authoritative(uuid,uuid) from public,anon,authenticated;

create or replace function public.send_friend_request(other_user uuid) returns void language plpgsql security definer set search_path='' as $$
begin if other_user=auth.uid() then raise exception 'Cannot friend yourself'; end if;
insert into public.friend_requests(from_user,to_user) values(auth.uid(),other_user) on conflict(from_user,to_user) do nothing; end $$;
create or replace function public.accept_friend_request(request_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare r public.friend_requests;
begin select * into r from public.friend_requests where id=request_id and to_user=auth.uid() and status='pending' for update;
if not found then raise exception 'Request unavailable'; end if;
insert into public.friendships(user_a,user_b) values(least(r.from_user,r.to_user),greatest(r.from_user,r.to_user)) on conflict do nothing;
update public.friend_requests set status='accepted' where id=request_id; end $$;

create view public.online_players with (security_invoker=true) as
select p.id,p.first_name,p.last_name,coalesce(pr.is_online,false) is_online,pr.last_seen,w.balance
from public.profiles p join public.player_presence pr on pr.user_id=p.id join public.wallets w on w.user_id=p.id;

alter table public.profiles enable row level security; alter table public.private_profiles enable row level security;
alter table public.fica_documents enable row level security; alter table public.player_presence enable row level security;
alter table public.wallets enable row level security; alter table public.wallet_ledger enable row level security;
alter table public.daily_coin_claims enable row level security; alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security; alter table public.challenges enable row level security;
alter table public.game_sessions enable row level security; alter table public.messages enable row level security;
create policy "authenticated profiles" on public.profiles for select to authenticated using(true);
create policy "own private profile" on public.private_profiles for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "own fica metadata" on public.fica_documents for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "presence visible" on public.player_presence for select to authenticated using(true);
create policy "own wallet" on public.wallets for select to authenticated using(user_id=auth.uid());
create policy "own ledger" on public.wallet_ledger for select to authenticated using(user_id=auth.uid());
create policy "own claims" on public.daily_coin_claims for select to authenticated using(user_id=auth.uid());
create policy "involved friend requests" on public.friend_requests for select to authenticated using(auth.uid() in(from_user,to_user));
create policy "own friendships" on public.friendships for select to authenticated using(auth.uid() in(user_a,user_b));
create policy "involved challenges" on public.challenges for select to authenticated using(auth.uid() in(from_player,to_player));
create policy "involved games" on public.game_sessions for select to authenticated using(auth.uid() in(player_one,player_two));
create policy "authenticated chat read" on public.messages for select to authenticated using(true);
create policy "send own message" on public.messages for insert to authenticated with check(sender_id=auth.uid());

insert into storage.buckets(id,name,public) values('fica-documents','fica-documents',false) on conflict(id) do nothing;
create policy "upload own fica" on storage.objects for insert to authenticated with check(bucket_id='fica-documents' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "read own fica" on storage.objects for select to authenticated using(bucket_id='fica-documents' and (storage.foldername(name))[1]=auth.uid()::text);
grant select on public.online_players to authenticated;
grant select on public.profiles,public.private_profiles,public.fica_documents,public.player_presence,public.wallets,public.wallet_ledger,public.daily_coin_claims,public.friend_requests,public.friendships,public.challenges,public.game_sessions,public.messages to authenticated;
grant insert,update on public.private_profiles,public.fica_documents,public.messages to authenticated;
revoke all on function public.claim_daily_coins() from public,anon,authenticated;
revoke all on function public.set_player_presence(boolean) from public,anon,authenticated;
revoke all on function public.create_challenge(uuid,integer) from public,anon,authenticated;
revoke all on function public.accept_challenge(uuid) from public,anon,authenticated;
revoke all on function public.send_friend_request(uuid) from public,anon,authenticated;
revoke all on function public.accept_friend_request(uuid) from public,anon,authenticated;
grant execute on function public.claim_daily_coins() to authenticated;
grant execute on function public.set_player_presence(boolean) to authenticated;
grant execute on function public.create_challenge(uuid,integer) to authenticated;
grant execute on function public.accept_challenge(uuid) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.accept_friend_request(uuid) to authenticated;
