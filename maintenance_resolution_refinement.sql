Maintenance module refinement: contractors + resolution metadata
Run in Supabase SQL Editor as project admin.

1) Contractors table
create table if not exists public.contractors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  phone text not null,
  specialty text not null default 'General Handyman',
  reliability_score double precision not null default 0,
  location_scope text not null default 'unscoped',
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.contractors
  add column if not exists organization_id uuid;

alter table public.contractors
  add column if not exists reliability_score double precision not null default 0;

alter table public.contractors
  add column if not exists specialty text not null default 'General Handyman';

alter table public.contractors
  add column if not exists updated_at timestamptz not null default now();

update public.contractors c
set organization_id = p.organization_id
from public.profiles p
where p.id = c.created_by
  and c.organization_id is null;

alter table public.contractors
  alter column organization_id set not null;

create unique index if not exists idx_contractors_org_phone_unique
  on public.contractors(organization_id, phone);

create index if not exists idx_contractors_created_by on public.contractors(created_by);
create index if not exists idx_contractors_organization_id on public.contractors(organization_id);
create index if not exists idx_contractors_specialty on public.contractors(specialty);
create index if not exists idx_contractors_reliability_score on public.contractors(reliability_score desc);
create index if not exists idx_contractors_location_scope on public.contractors(location_scope);

alter table public.contractors
  add column if not exists location_scope text not null default 'unscoped';

alter table public.contractors enable row level security;

drop policy if exists "contractors_select_own" on public.contractors;
create policy "contractors_select_own"
on public.contractors
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.organization_id = public.contractors.organization_id
  )
  or created_by = auth.uid()
);

drop policy if exists "contractors_insert_own" on public.contractors;
create policy "contractors_insert_own"
on public.contractors
for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.organization_id = organization_id
  )
  or created_by = auth.uid()
);

drop policy if exists "contractors_update_own" on public.contractors;
create policy "contractors_update_own"
on public.contractors
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.organization_id = public.contractors.organization_id
  )
  or created_by = auth.uid()
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.organization_id = organization_id
  )
  or created_by = auth.uid()
);

drop policy if exists "contractors_delete_own" on public.contractors;
create policy "contractors_delete_own"
on public.contractors
for delete
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.organization_id = public.contractors.organization_id
  )
  or created_by = auth.uid()
);

2) maintenance_requests refinements
alter table public.maintenance_requests
  add column if not exists category text default 'General',
  add column if not exists resolved_at timestamptz,
  add column if not exists after_image_url text,
  add column if not exists contractor_id uuid references public.contractors(id) on delete set null;

actual_cost may already exist from earlier schema; keep this idempotent.
alter table public.maintenance_requests
  add column if not exists actual_cost numeric(10,2);

create index if not exists idx_maintenance_requests_category on public.maintenance_requests(category);
create index if not exists idx_maintenance_requests_contractor_id on public.maintenance_requests(contractor_id);
create index if not exists idx_maintenance_requests_resolved_at on public.maintenance_requests(resolved_at desc);
