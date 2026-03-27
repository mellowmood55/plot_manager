-- schema_fix.sql
-- Phase 3 canonical schema: organizations -> properties -> units -> tenants
-- Run this in Supabase SQL editor.

create extension if not exists pgcrypto;

-- =========================
-- PROFILES
-- =========================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'User',
  organization_id uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- ORGANIZATIONS
-- =========================
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- PROPERTIES
-- =========================
create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  location text,
  property_type text not null default 'Residential',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- UNITS
-- =========================
create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  unit_number text not null,
  rent_amount numeric(12,2) not null default 0,
  status text not null default 'vacant' check (status in ('vacant', 'occupied')),
  tenant_id uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, unit_number)
);

-- =========================
-- TENANTS
-- =========================
create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null unique references public.units(id) on delete cascade,
  full_name text not null,
  phone_number text not null,
  national_id text not null,
  occupants_count int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure units.tenant_id exists before creating the FK constraint
alter table public.units add column if not exists tenant_id uuid;

-- add FK from units.tenant_id to tenants.id after tenants table exists
alter table public.units
  drop constraint if exists units_tenant_id_fkey;

alter table public.units
  add constraint units_tenant_id_fkey
  foreign key (tenant_id) references public.tenants(id) on delete set null;

-- Ensure expected columns exist on existing tables
alter table public.properties add column if not exists property_type text not null default 'Residential';
alter table public.units add column if not exists unit_number text;
alter table public.units add column if not exists rent_amount numeric(12,2) not null default 0;
alter table public.units add column if not exists status text not null default 'vacant';
alter table public.tenants add column if not exists phone_number text;
alter table public.tenants add column if not exists occupants_count int not null default 1;

-- Backfill unit_number from legacy name when needed
update public.units
set unit_number = coalesce(unit_number, name)
where unit_number is null;

-- Backfill phone_number from legacy phone when needed
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'tenants'
      and column_name = 'phone'
  ) then
    execute 'update public.tenants set phone_number = coalesce(phone_number, phone) where phone_number is null';
  end if;
end $$;

-- keep not-null after backfill
alter table public.units alter column unit_number set not null;
alter table public.tenants alter column phone_number set not null;

-- =========================
-- RLS
-- =========================
alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.properties enable row level security;
alter table public.units enable row level security;
alter table public.tenants enable row level security;

-- Drop old policies for idempotency
-- profiles
 drop policy if exists "profiles_select_own" on public.profiles;
 drop policy if exists "profiles_insert_own" on public.profiles;
 drop policy if exists "profiles_update_own" on public.profiles;

-- organizations
 drop policy if exists "organizations_select_own_org" on public.organizations;
 drop policy if exists "organizations_insert_own" on public.organizations;
 drop policy if exists "organizations_update_own_org" on public.organizations;

-- properties
 drop policy if exists "properties_select_own_org" on public.properties;
 drop policy if exists "properties_insert_own_org" on public.properties;
 drop policy if exists "properties_update_own_org" on public.properties;
 drop policy if exists "properties_delete_own_org" on public.properties;

-- units
 drop policy if exists "units_select_own_org" on public.units;
 drop policy if exists "units_insert_own_org" on public.units;
 drop policy if exists "units_update_own_org" on public.units;
 drop policy if exists "units_delete_own_org" on public.units;

-- tenants
 drop policy if exists "tenants_select_own_org" on public.tenants;
 drop policy if exists "tenants_insert_own_org" on public.tenants;
 drop policy if exists "tenants_update_own_org" on public.tenants;
 drop policy if exists "tenants_delete_own_org" on public.tenants;

-- Profiles policies
create policy "profiles_select_own"
on public.profiles
for select
using (auth.uid() = id);

create policy "profiles_insert_own"
on public.profiles
for insert
with check (auth.uid() = id);

create policy "profiles_update_own"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- Organizations policies
create policy "organizations_select_own_org"
on public.organizations
for select
using (
  created_by = auth.uid()
  or id in (
    select p.organization_id from public.profiles p where p.id = auth.uid()
  )
);

create policy "organizations_insert_own"
on public.organizations
for insert
with check (created_by = auth.uid());

create policy "organizations_update_own_org"
on public.organizations
for update
using (
  created_by = auth.uid()
  or id in (
    select p.organization_id from public.profiles p where p.id = auth.uid()
  )
)
with check (
  created_by = auth.uid()
  or id in (
    select p.organization_id from public.profiles p where p.id = auth.uid()
  )
);

-- Properties policies
create policy "properties_select_own_org"
on public.properties
for select
using (
  organization_id in (
    select p.organization_id from public.profiles p where p.id = auth.uid()
  )
);

create policy "properties_insert_own_org"
on public.properties
for insert
with check (
  organization_id in (
    select p.organization_id from public.profiles p where p.id = auth.uid()
  )
);

create policy "properties_update_own_org"
on public.properties
for update
using (
  organization_id in (
    select p.organization_id from public.profiles p where p.id = auth.uid()
  )
)
with check (
  organization_id in (
    select p.organization_id from public.profiles p where p.id = auth.uid()
  )
);

create policy "properties_delete_own_org"
on public.properties
for delete
using (
  organization_id in (
    select p.organization_id from public.profiles p where p.id = auth.uid()
  )
);

-- Units policies
create policy "units_select_own_org"
on public.units
for select
using (
  property_id in (
    select pr.id
    from public.properties pr
    join public.profiles p on p.organization_id = pr.organization_id
    where p.id = auth.uid()
  )
);

create policy "units_insert_own_org"
on public.units
for insert
with check (
  property_id in (
    select pr.id
    from public.properties pr
    join public.profiles p on p.organization_id = pr.organization_id
    where p.id = auth.uid()
  )
);

create policy "units_update_own_org"
on public.units
for update
using (
  property_id in (
    select pr.id
    from public.properties pr
    join public.profiles p on p.organization_id = pr.organization_id
    where p.id = auth.uid()
  )
)
with check (
  property_id in (
    select pr.id
    from public.properties pr
    join public.profiles p on p.organization_id = pr.organization_id
    where p.id = auth.uid()
  )
);

create policy "units_delete_own_org"
on public.units
for delete
using (
  property_id in (
    select pr.id
    from public.properties pr
    join public.profiles p on p.organization_id = pr.organization_id
    where p.id = auth.uid()
  )
);

-- Tenants policies
create policy "tenants_select_own_org"
on public.tenants
for select
using (
  unit_id in (
    select u.id
    from public.units u
    join public.properties pr on pr.id = u.property_id
    join public.profiles p on p.organization_id = pr.organization_id
    where p.id = auth.uid()
  )
);

create policy "tenants_insert_own_org"
on public.tenants
for insert
with check (
  unit_id in (
    select u.id
    from public.units u
    join public.properties pr on pr.id = u.property_id
    join public.profiles p on p.organization_id = pr.organization_id
    where p.id = auth.uid()
  )
);

create policy "tenants_update_own_org"
on public.tenants
for update
using (
  unit_id in (
    select u.id
    from public.units u
    join public.properties pr on pr.id = u.property_id
    join public.profiles p on p.organization_id = pr.organization_id
    where p.id = auth.uid()
  )
)
with check (
  unit_id in (
    select u.id
    from public.units u
    join public.properties pr on pr.id = u.property_id
    join public.profiles p on p.organization_id = pr.organization_id
    where p.id = auth.uid()
  )
);

create policy "tenants_delete_own_org"
on public.tenants
for delete
using (
  unit_id in (
    select u.id
    from public.units u
    join public.properties pr on pr.id = u.property_id
    join public.profiles p on p.organization_id = pr.organization_id
    where p.id = auth.uid()
  )
);
