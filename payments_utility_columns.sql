-- Add utility billing fields to payments for water charge tracking.
alter table public.payments
  add column if not exists water_reading_previous numeric(12, 2),
  add column if not exists water_reading_current numeric(12, 2),
  add column if not exists utility_amount numeric(12, 2);

-- Optional check: reading current cannot be below previous when both are present.
alter table public.payments
  drop constraint if exists payments_water_reading_check;

alter table public.payments
  add constraint payments_water_reading_check
  check (
    water_reading_previous is null
    or water_reading_current is null
    or water_reading_current >= water_reading_previous
  );
