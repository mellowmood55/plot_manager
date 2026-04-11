-- Fix: Supabase "Database error saving new user" during auth.signUp
--
-- Run this in Supabase SQL editor, top to bottom.
-- It removes custom auth.users triggers/functions that commonly break signup,
-- then validates that the public.profiles table is compatible.

-- 1) Inspect custom triggers on auth.users
select t.tgname as trigger_name,
       p.proname as function_name,
       n.nspname as function_schema
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace ns on ns.oid = c.relnamespace
join pg_proc p on p.oid = t.tgfoid
join pg_namespace n on n.oid = p.pronamespace
where ns.nspname = 'auth'
  and c.relname = 'users'
  and not t.tgisinternal
order by t.tgname;

-- 2) Drop all custom auth.users triggers (keeps internal Supabase triggers)
do $$
declare
  r record;
begin
  for r in
    select t.tgname
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'auth'
      and c.relname = 'users'
      and not t.tgisinternal
  loop
    execute format('drop trigger if exists %I on auth.users', r.tgname);
  end loop;
end $$;

-- 3) Remove old helper functions if they exist
-- (safe even if they are not present)
drop function if exists public.handle_new_user() cascade;
drop function if exists public.on_auth_user_created() cascade;

-- 4) Ensure profiles schema can accept app-side profile upsert on login
alter table if exists public.profiles
  add column if not exists full_name text not null default 'User',
  add column if not exists role text not null default 'landlord',
  add column if not exists unit_id uuid null;

update public.profiles
set role = case
  when role is null then 'landlord'
  when lower(trim(role)) in ('tenant', 'renter', 'lessee') then 'tenant'
  when lower(trim(role)) in ('landlord', 'owner', 'admin', 'manager') then 'landlord'
  else 'landlord'
end;

alter table public.profiles
  alter column role set default 'landlord',
  alter column role set not null;

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check check (role in ('landlord', 'tenant'));

-- 5) Final verification: should return zero rows
select t.tgname
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace ns on ns.oid = c.relnamespace
where ns.nspname = 'auth'
  and c.relname = 'users'
  and not t.tgisinternal;
