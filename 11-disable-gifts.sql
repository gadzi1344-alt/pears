-- Отключает подарки, но сохраняет существующие балансы и коллекции.
-- Можно выполнить повторно. Другие таблицы и аккаунты не изменяются.
begin;
drop trigger if exists pear_profile_make_wallet on public.profiles;
do $$
declare t text; f text;
begin
 foreach t in array array['public.pear_wallets','public.pear_gift_catalog','public.pear_gifts'] loop
  if to_regclass(t) is not null then execute format('revoke all on table %s from public, anon, authenticated',t); end if;
 end loop;
 foreach f in array array['public.pear_send_gift(uuid,text,uuid)','public.pear_set_gift_hidden(uuid,boolean)','public.pear_sell_gift(uuid)','public.pear_make_wallet()'] loop
  if to_regprocedure(f) is not null then execute format('revoke all on function %s from public, anon, authenticated',f); end if;
 end loop;
end $$;
commit;
