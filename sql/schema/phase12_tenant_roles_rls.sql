-- Phase 12: Tenant portal role model + restricted RLS access
-- Run in Supabase SQL Editor.

-- =========================
-- Auth signup -> profiles sync
-- Fixes "Database error saving new user" when an old/missing trigger exists.
-- =========================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1), 'User'),
    'landlord'
  )
  on conflict (id) do update
    set full_name = coalesce(excluded.full_name, public.profiles.full_name);

  return new;
exception
  when others then
    -- Bubble explicit error so Supabase logs reveal root cause.
    raise exception 'handle_new_user failed: %', sqlerrm;
end;
$$;

do $$
declare
  trigger_record record;
begin
  for trigger_record in
    select tgname
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'auth'
      and c.relname = 'users'
      and not t.tgisinternal
  loop
    execute format('drop trigger if exists %I on auth.users', trigger_record.tgname);
  end loop;
end $$;

-- Do not recreate an auth.users trigger here.
-- The app now backfills profiles after successful login/sign-in, which avoids
-- signup failures caused by trigger/permissions issues in Supabase Auth.

-- =========================
-- Profiles: role + tenant unit link
-- =========================
alter table public.profiles
  add column if not exists role text not null default 'landlord',
  add column if not exists unit_id uuid null references public.units(id) on delete set null;

-- Normalize legacy values before enforcing the role check constraint.
-- Any unknown/blank/null role is treated as landlord by default.
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

-- =========================
-- Payments policies
-- Landlord: can SELECT all rows in their organization
-- Tenant: can SELECT only rows for their assigned unit
-- =========================
drop policy if exists "Landlords can view payments for owned units" on public.payments;
drop policy if exists "Landlords can insert payments for owned units" on public.payments;
drop policy if exists "Landlords can update payments for owned units" on public.payments;
drop policy if exists "Landlords can delete payments for owned units" on public.payments;

-- New names for role-aware policies
 drop policy if exists "payments_select_role_scoped" on public.payments;
 drop policy if exists "payments_insert_landlord_only" on public.payments;
 drop policy if exists "payments_update_landlord_only" on public.payments;
 drop policy if exists "payments_delete_landlord_only" on public.payments;

create policy "payments_select_role_scoped"
on public.payments
for select
using (
  (
    exists (
      select 1
      from public.profiles pr
      join public.units u on u.id = payments.unit_id
      join public.properties p on p.id = u.property_id
      where pr.id = auth.uid()
        and pr.role = 'landlord'
        and pr.organization_id = p.organization_id
    )
  )
  or
  (
    exists (
      select 1
      from public.profiles pr
      where pr.id = auth.uid()
        and pr.role = 'tenant'
        and pr.unit_id = payments.unit_id
    )
  )
);

create policy "payments_insert_landlord_only"
on public.payments
for insert
with check (
  exists (
    select 1
    from public.profiles pr
    join public.units u on u.id = payments.unit_id
    join public.properties p on p.id = u.property_id
    where pr.id = auth.uid()
      and pr.role = 'landlord'
      and pr.organization_id = p.organization_id
  )
);

create policy "payments_update_landlord_only"
on public.payments
for update
using (
  exists (
    select 1
    from public.profiles pr
    join public.units u on u.id = payments.unit_id
    join public.properties p on p.id = u.property_id
    where pr.id = auth.uid()
      and pr.role = 'landlord'
      and pr.organization_id = p.organization_id
  )
)
with check (
  exists (
    select 1
    from public.profiles pr
    join public.units u on u.id = payments.unit_id
    join public.properties p on p.id = u.property_id
    where pr.id = auth.uid()
      and pr.role = 'landlord'
      and pr.organization_id = p.organization_id
  )
);

create policy "payments_delete_landlord_only"
on public.payments
for delete
using (
  exists (
    select 1
    from public.profiles pr
    join public.units u on u.id = payments.unit_id
    join public.properties p on p.id = u.property_id
    where pr.id = auth.uid()
      and pr.role = 'landlord'
      and pr.organization_id = p.organization_id
  )
);

-- =========================
-- Maintenance requests policies
-- Landlord: can SELECT/INSERT/UPDATE/DELETE in their organization
-- Tenant: can SELECT only their unit and can INSERT only their unit
-- =========================
drop policy if exists "Select maintenance requests - landlord organization access" on public.maintenance_requests;
drop policy if exists "Insert maintenance requests - landlord organization access" on public.maintenance_requests;
drop policy if exists "Update maintenance requests - landlord organization access" on public.maintenance_requests;
drop policy if exists "Delete maintenance requests - landlord organization access" on public.maintenance_requests;

 drop policy if exists "maintenance_select_role_scoped" on public.maintenance_requests;
 drop policy if exists "maintenance_insert_role_scoped" on public.maintenance_requests;
 drop policy if exists "maintenance_update_landlord_only" on public.maintenance_requests;
 drop policy if exists "maintenance_delete_landlord_only" on public.maintenance_requests;

create policy "maintenance_select_role_scoped"
on public.maintenance_requests
for select
to authenticated
using (
  (
    exists (
      select 1
      from public.profiles pr
      join public.units u on u.id = maintenance_requests.unit_id
      join public.properties p on p.id = u.property_id
      where pr.id = auth.uid()
        and pr.role = 'landlord'
        and pr.organization_id = p.organization_id
    )
  )
  or
  (
    exists (
      select 1
      from public.profiles pr
      where pr.id = auth.uid()
        and pr.role = 'tenant'
        and pr.unit_id = maintenance_requests.unit_id
    )
  )
);

create policy "maintenance_insert_role_scoped"
on public.maintenance_requests
for insert
to authenticated
with check (
  (
    exists (
      select 1
      from public.profiles pr
      join public.units u on u.id = maintenance_requests.unit_id
      join public.properties p on p.id = u.property_id
      where pr.id = auth.uid()
        and pr.role = 'landlord'
        and pr.organization_id = p.organization_id
    )
  )
  or
  (
    exists (
      select 1
      from public.profiles pr
      where pr.id = auth.uid()
        and pr.role = 'tenant'
        and pr.unit_id = maintenance_requests.unit_id
    )
  )
);

create policy "maintenance_update_landlord_only"
on public.maintenance_requests
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles pr
    join public.units u on u.id = maintenance_requests.unit_id
    join public.properties p on p.id = u.property_id
    where pr.id = auth.uid()
      and pr.role = 'landlord'
      and pr.organization_id = p.organization_id
  )
)
with check (
  exists (
    select 1
    from public.profiles pr
    join public.units u on u.id = maintenance_requests.unit_id
    join public.properties p on p.id = u.property_id
    where pr.id = auth.uid()
      and pr.role = 'landlord'
      and pr.organization_id = p.organization_id
  )
);

create policy "maintenance_delete_landlord_only"
on public.maintenance_requests
for delete
to authenticated
using (
  exists (
    select 1
    from public.profiles pr
    join public.units u on u.id = maintenance_requests.unit_id
    join public.properties p on p.id = u.property_id
    where pr.id = auth.uid()
      and pr.role = 'landlord'
      and pr.organization_id = p.organization_id
  )
);
