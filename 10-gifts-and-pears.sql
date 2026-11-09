-- Pear: подарки и внутренняя валюта. Только для существующего проекта Supabase.
-- Сначала резервная копия; скрипт можно безопасно повторять без повторного начисления.
begin;
create table if not exists public.pear_wallets (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 balance bigint not null default 100 check (balance >= 0)
);
create table if not exists public.pear_gift_catalog (
 id text primary key, name text not null, price integer not null check(price > 0), active boolean not null default true
);
create table if not exists public.pear_gifts (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 sender_id uuid references public.profiles(id) on delete set null,
 gift_type text not null references public.pear_gift_catalog(id),
 purchase_price integer not null check(purchase_price > 0),
 request_id uuid not null,
 hidden boolean not null default false,
 created_at timestamptz not null default now(),
 sold_at timestamptz,
 unique(sender_id,request_id)
);
create index if not exists pear_gifts_collection_idx on public.pear_gifts(owner_id,created_at desc) where sold_at is null;
insert into public.pear_gift_catalog(id,name,price) values ('rose','Роза',15),('heart','Сердце',25),('star','Звезда',40) on conflict(id) do nothing;
alter table public.pear_wallets enable row level security;
alter table public.pear_gift_catalog enable row level security;
alter table public.pear_gifts enable row level security;
revoke all on public.pear_wallets,public.pear_gift_catalog,public.pear_gifts from public,anon,authenticated;
grant select on public.pear_wallets,public.pear_gift_catalog,public.pear_gifts to authenticated;
drop policy if exists pear_wallet_read_self on public.pear_wallets;
create policy pear_wallet_read_self on public.pear_wallets for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists pear_catalog_read on public.pear_gift_catalog;
create policy pear_catalog_read on public.pear_gift_catalog for select to authenticated using(active);
drop policy if exists pear_gifts_read on public.pear_gifts;
create policy pear_gifts_read on public.pear_gifts for select to authenticated using(sold_at is null and (not hidden or owner_id=(select auth.uid())));

-- Начисление создаётся ровно один раз при создании профиля.
create or replace function public.pear_make_wallet() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.pear_wallets(user_id,balance) values(new.id,100) on conflict(user_id) do nothing;
 return new;
end $$;
revoke all on function public.pear_make_wallet() from public,anon,authenticated;
drop trigger if exists pear_profile_make_wallet on public.profiles;
create trigger pear_profile_make_wallet after insert on public.profiles for each row execute function public.pear_make_wallet();
-- Существующие профили получают 100 только если кошелька ещё нет.
insert into public.pear_wallets(user_id,balance) select id,100 from public.profiles on conflict(user_id) do nothing;

-- Все денежные операции выполняются в транзакции и только от имени вошедшего пользователя.
create or replace function public.pear_send_gift(p_owner uuid,p_type text,p_request uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); cost integer; current_balance bigint; prior public.pear_gifts%rowtype; new_id uuid;
begin
 if me is null then raise exception 'Not authenticated'; end if;
 if p_request is null or p_owner is null or p_type is null or p_owner=me then raise exception 'Invalid gift request'; end if;
 select w.balance into current_balance from public.pear_wallets w where w.user_id=me for update;
 if not found then raise exception 'Wallet unavailable'; end if;
 select * into prior from public.pear_gifts g where g.sender_id=me and g.request_id=p_request;
 if found then
  if prior.owner_id<>p_owner or prior.gift_type<>p_type then raise exception 'Request already used'; end if;
  return jsonb_build_object('gift_id',prior.id,'balance',current_balance,'replayed',true);
 end if;
 select c.price into cost from public.pear_gift_catalog c where c.id=p_type and c.active;
 if cost is null then raise exception 'Gift unavailable'; end if;
 if not exists(select 1 from public.profiles p where p.id=p_owner) then raise exception 'Profile unavailable'; end if;
 if current_balance < cost then raise exception 'Insufficient balance'; end if;
 update public.pear_wallets set balance=balance-cost where user_id=me returning balance into current_balance;
 insert into public.pear_gifts(owner_id,sender_id,gift_type,purchase_price,request_id) values(p_owner,me,p_type,cost,p_request) returning id into new_id;
 return jsonb_build_object('gift_id',new_id,'balance',current_balance,'replayed',false);
end $$;
create or replace function public.pear_set_gift_hidden(p_gift uuid,p_hidden boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or p_hidden is null then raise exception 'Invalid request'; end if;
 update public.pear_gifts set hidden=p_hidden where id=p_gift and owner_id=auth.uid() and sold_at is null;
 if not found then raise exception 'Gift unavailable'; end if;
end $$;
create or replace function public.pear_sell_gift(p_gift uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); cost integer; payout integer; new_balance bigint;
begin
 if me is null then raise exception 'Not authenticated'; end if;
 select g.purchase_price into cost from public.pear_gifts g where g.id=p_gift and g.owner_id=me and g.sold_at is null for update;
 if not found then raise exception 'Gift unavailable'; end if;
 payout:=cost-ceil(cost::numeric/10)::integer;
 update public.pear_gifts set sold_at=now() where id=p_gift;
 update public.pear_wallets set balance=balance+payout where user_id=me returning balance into new_balance;
 if not found then raise exception 'Wallet unavailable'; end if;
 return jsonb_build_object('payout',payout,'balance',new_balance);
end $$;
revoke all on function public.pear_send_gift(uuid,text,uuid),public.pear_set_gift_hidden(uuid,boolean),public.pear_sell_gift(uuid) from public,anon,authenticated;
grant execute on function public.pear_send_gift(uuid,text,uuid),public.pear_set_gift_hidden(uuid,boolean),public.pear_sell_gift(uuid) to authenticated;
commit;
