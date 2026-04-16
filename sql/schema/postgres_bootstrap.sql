-- Fresh PostgreSQL schema for Plot Manager (no seed data).
-- This setup is backend-authorized (no Supabase RLS/auth dependencies).

create extension if not exists pgcrypto;

create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text not null unique,
  phone text,
  password_hash text not null,
  role text not null default 'landlord' check (role in ('landlord', 'tenant')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key,
  full_name text not null default 'User',
  organization_id uuid null,
  role text not null default 'landlord' check (role in ('landlord', 'tenant')),
  unit_id uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  location text,
  property_type text not null default 'Residential',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  unit_number text not null,
  unit_type text,
  rent_amount numeric(12,2) not null default 0,
  balance_due numeric(12,2) not null default 0,
  status text not null default 'vacant' check (status in ('vacant', 'occupied')),
  tenant_id uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, unit_number)
);

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

alter table public.units
  drop constraint if exists units_tenant_id_fkey;

alter table public.units
  add constraint units_tenant_id_fkey
  foreign key (tenant_id) references public.tenants(id) on delete set null;

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id) on delete cascade,
  tenant_id uuid references public.tenants(id) on delete set null,
  amount_paid numeric(12,2) not null check (amount_paid > 0),
  transaction_ref text,
  payment_method text not null,
  payment_date date not null default current_date,
  water_reading_previous numeric(12,2),
  water_reading_current numeric(12,2),
  utility_amount numeric(12,2),
  created_at timestamptz not null default now()
);

create table if not exists public.contractors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  specialty text not null,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  reliability_score numeric(3,2) not null default 0,
  location_scope text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from pg_type where typname = 'maintenance_priority') then
    create type maintenance_priority as enum ('low', 'medium', 'high');
  end if;

  if not exists (select 1 from pg_type where typname = 'maintenance_status') then
    create type maintenance_status as enum ('open', 'in_progress', 'completed', 'closed');
  end if;
end $$;

create table if not exists public.maintenance_requests (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id) on delete cascade,
  title text not null,
  description text,
  category text,
  priority maintenance_priority not null default 'medium',
  status maintenance_status not null default 'open',
  estimated_cost numeric(10,2),
  actual_cost numeric(10,2),
  image_url text,
  after_image_url text,
  resolved_at timestamptz,
  contractor_id uuid references public.contractors(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.unit_configurations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  unit_type_name text not null,
  default_rent numeric(12,2) not null default 0,
  min_occupants int not null default 1,
  max_occupants int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, unit_type_name)
);

create index if not exists idx_app_users_email on public.app_users(email);
create index if not exists idx_profiles_org on public.profiles(organization_id);
create index if not exists idx_properties_organization on public.properties(organization_id);
create index if not exists idx_units_property on public.units(property_id);
create index if not exists idx_tenants_unit on public.tenants(unit_id);
create index if not exists idx_payments_unit on public.payments(unit_id);
create index if not exists idx_payments_date on public.payments(payment_date);
create index if not exists idx_maintenance_unit on public.maintenance_requests(unit_id);
create index if not exists idx_maintenance_status on public.maintenance_requests(status);
create index if not exists idx_contractors_org on public.contractors(organization_id);
