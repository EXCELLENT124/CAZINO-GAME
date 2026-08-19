-- Advisor-driven hardening after deployment verification.
revoke all on function public.new_cazino_user() from public, anon, authenticated;
revoke all on function public.rls_auto_enable() from public, anon, authenticated;

create index if not exists fica_documents_user_id_idx on public.fica_documents(user_id);
create index if not exists friend_requests_to_user_idx on public.friend_requests(to_user);
create index if not exists friendships_user_b_idx on public.friendships(user_b);
create index if not exists game_events_actor_id_idx on public.game_events(actor_id);
create index if not exists game_sessions_winner_id_idx on public.game_sessions(winner_id);
create index if not exists messages_sender_id_idx on public.messages(sender_id);
create index if not exists wallet_ledger_user_id_idx on public.wallet_ledger(user_id);

drop policy if exists "own private profile" on public.private_profiles;
create policy "own private profile" on public.private_profiles for all to authenticated
using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists "own fica metadata" on public.fica_documents;
create policy "own fica metadata" on public.fica_documents for all to authenticated
using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists "own wallet" on public.wallets;
create policy "own wallet" on public.wallets for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists "own ledger" on public.wallet_ledger;
create policy "own ledger" on public.wallet_ledger for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists "own claims" on public.daily_coin_claims;
create policy "own claims" on public.daily_coin_claims for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists "involved friend requests" on public.friend_requests;
create policy "involved friend requests" on public.friend_requests for select to authenticated
using((select auth.uid()) in(from_user,to_user));
drop policy if exists "own friendships" on public.friendships;
create policy "own friendships" on public.friendships for select to authenticated
using((select auth.uid()) in(user_a,user_b));
drop policy if exists "involved challenges" on public.challenges;
create policy "involved challenges" on public.challenges for select to authenticated
using((select auth.uid()) in(from_player,to_player));
drop policy if exists "involved games" on public.game_sessions;
create policy "involved games" on public.game_sessions for select to authenticated
using((select auth.uid()) in(player_one,player_two));
drop policy if exists "send own message" on public.messages;
create policy "send own message" on public.messages for insert to authenticated
with check(sender_id=(select auth.uid()));

create policy "update own fica files" on storage.objects for update to authenticated
using(bucket_id='fica-documents' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='fica-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);
