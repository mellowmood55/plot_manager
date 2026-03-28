-- Maintenance module refinement: contractors + resolution metadata
-- Run in Supabase SQL Editor as project admin.

-- 1) Contractors table
create table if not exists public.contractors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  specialty text not null,
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists idx_contractors_created_by on public.contractors(created_by);
create index if not exists idx_contractors_specialty on public.contractors(specialty);

alter table public.contractors enable row level security;

drop policy if exists "contractors_select_own" on public.contractors;
create policy "contractors_select_own"
on public.contractors
for select
to authenticated
using (created_by = auth.uid());

drop policy if exists "contractors_insert_own" on public.contractors;
create policy "contractors_insert_own"
on public.contractors
for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists "contractors_update_own" on public.contractors;
create policy "contractors_update_own"
on public.contractors
for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

drop policy if exists "contractors_delete_own" on public.contractors;
create policy "contractors_delete_own"
on public.contractors
for delete
to authenticated
using (created_by = auth.uid());

-- 2) maintenance_requests refinements
alter table public.maintenance_requests
  add column if not exists category text default 'General',
  add column if not exists resolved_at timestamptz,
  add column if not exists after_image_url text,
  add column if not exists contractor_id uuid references public.contractors(id) on delete set null;

-- actual_cost may already exist from earlier schema; keep this idempotent.
alter table public.maintenance_requests
  add column if not exists actual_cost numeric(10,2);

create index if not exists idx_maintenance_requests_category on public.maintenance_requests(category);
create index if not exists idx_maintenance_requests_contractor_id on public.maintenance_requests(contractor_id);
create index if not exists idx_maintenance_requests_resolved_at on public.maintenance_requests(resolved_at desc);
