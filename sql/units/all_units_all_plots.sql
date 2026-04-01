-- All units for all plots (includes organization, plot, unit, and tenant occupancy snapshot)
SELECT
  o.name AS organization_name,
  p.id AS plot_id,
  p.name AS plot_name,
  p.property_type,
  u.id AS unit_id,
  u.unit_number,
  u.unit_type,
  u.status,
  u.rent_amount,
  t.full_name AS tenant_name,
  t.phone_number,
  t.national_id,
  t.occupants_count
FROM public.units u
JOIN public.properties p ON p.id = u.property_id
LEFT JOIN public.organizations o ON o.id = p.organization_id
LEFT JOIN public.tenants t ON t.unit_id = u.id
ORDER BY p.name, u.unit_number;
