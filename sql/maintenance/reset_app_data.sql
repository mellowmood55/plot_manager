-- Plot Manager data reset for Supabase/PostgreSQL.
-- WARNING: This permanently deletes all app data in public tables.

begin;

truncate table public.payments restart identity cascade;
truncate table public.maintenance_requests restart identity cascade;
truncate table public.contractors restart identity cascade;
truncate table public.tenants restart identity cascade;
truncate table public.units restart identity cascade;
truncate table public.properties restart identity cascade;
truncate table public.unit_configurations restart identity cascade;
truncate table public.organizations restart identity cascade;
truncate table public.profiles restart identity cascade;
truncate table public.app_users restart identity cascade;

commit;

-- Optional: If you also want to remove Supabase Auth users,
-- do it from the Supabase Dashboard: Authentication > Users.
-- (This script only resets your app tables in public schema.)
