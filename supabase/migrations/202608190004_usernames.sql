alter table public.profiles add column if not exists username text;
alter table public.profiles add constraint profiles_username_format
  check (username is null or username ~ '^[a-z0-9_]{3,20}$');
create unique index if not exists profiles_username_unique_idx
  on public.profiles(lower(username)) where username is not null;

create or replace function public.new_cazino_user() returns trigger
language plpgsql security definer set search_path='' as $$
declare requested_username text;
begin
  requested_username := lower(trim(coalesce(new.raw_user_meta_data->>'username','')));
  if requested_username !~ '^[a-z0-9_]{3,20}$' then
    raise exception 'Username must contain 3-20 lowercase letters, numbers, or underscores';
  end if;
  insert into public.profiles(id,first_name,last_name,username)
    values(new.id,coalesce(new.raw_user_meta_data->>'first_name','Player'),
      coalesce(new.raw_user_meta_data->>'last_name',''),requested_username);
  insert into public.private_profiles(user_id) values(new.id);
  insert into public.player_presence(user_id) values(new.id);
  insert into public.wallets(user_id,balance) values(new.id,0);
  return new;
end $$;
revoke all on function public.new_cazino_user() from public,anon,authenticated;

create or replace view public.online_players with (security_invoker=true) as
select p.id,p.first_name,p.last_name,coalesce(pr.is_online,false) is_online,
  pr.last_seen,w.balance,p.username
from public.profiles p join public.player_presence pr on pr.user_id=p.id
join public.wallets w on w.user_id=p.id;
grant select on public.online_players to authenticated;
