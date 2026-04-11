-- Cleanup script: drop public tables not used by the app schema.
--
-- Usage:
-- 1) Run PREVIEW block first to see candidates.
-- 2) Set execute_drop := true in EXECUTE block to actually drop.
--
-- Core app tables kept:
-- profiles, organizations, properties, units, tenants,
-- payments, maintenance_requests, contractors, unit_configurations

-- =========================
-- PREVIEW ONLY
-- =========================
do $$
declare
  keep_tables text[] := array[
    'profiles',
    'organizations',
    'properties',
    'units',
    'tenants',
    'payments',
    'maintenance_requests',
    'contractors',
    'unit_configurations'
  ];
  table_name text;
begin
  raise notice 'Previewing non-whitelisted public tables...';

  for table_name in
    select t.table_name
    from information_schema.tables t
    where t.table_schema = 'public'
      and t.table_type = 'BASE TABLE'
      and t.table_name <> all(keep_tables)
    order by t.table_name
  loop
    raise notice 'DROP candidate: public.%', table_name;
  end loop;
end $$;

-- =========================
-- EXECUTE DROP
-- =========================
do $$
declare
  execute_drop boolean := true; -- change to true to perform deletion
  keep_tables text[] := array[
    'profiles',
    'organizations',
    'properties',
    'units',
    'tenants',
    'payments',
    'maintenance_requests',
    'contractors',
    'unit_configurations'
  ];
  table_name text;
begin
  if not execute_drop then
    raise notice 'execute_drop=false, no tables were dropped.';
    return;
  end if;

  for table_name in
    select t.table_name
    from information_schema.tables t
    where t.table_schema = 'public'
      and t.table_type = 'BASE TABLE'
      and t.table_name <> all(keep_tables)
    order by t.table_name
  loop
    execute format('drop table if exists public.%I cascade', table_name);
    raise notice 'Dropped: public.%', table_name;
  end loop;
end $$;
