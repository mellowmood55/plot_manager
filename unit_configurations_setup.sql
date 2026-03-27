-- Create unit_configurations table
CREATE TABLE IF NOT EXISTS public.unit_configurations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  unit_type_name TEXT NOT NULL,
  default_rent DECIMAL(12, 2) NOT NULL DEFAULT 0,
  min_occupants INTEGER NOT NULL DEFAULT 1,
  max_occupants INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  CHECK (min_occupants >= 1),
  CHECK (max_occupants >= min_occupants),
  UNIQUE(organization_id, unit_type_name)
);

ALTER TABLE public.unit_configurations
  ADD COLUMN IF NOT EXISTS min_occupants INTEGER NOT NULL DEFAULT 1;

ALTER TABLE public.unit_configurations
  ADD COLUMN IF NOT EXISTS max_occupants INTEGER NOT NULL DEFAULT 1;

ALTER TABLE public.unit_configurations
  DROP CONSTRAINT IF EXISTS unit_configurations_min_occupants_check;

ALTER TABLE public.unit_configurations
  ADD CONSTRAINT unit_configurations_min_occupants_check CHECK (min_occupants >= 1);

ALTER TABLE public.unit_configurations
  DROP CONSTRAINT IF EXISTS unit_configurations_max_occupants_check;

ALTER TABLE public.unit_configurations
  ADD CONSTRAINT unit_configurations_max_occupants_check CHECK (max_occupants >= min_occupants);

CREATE UNIQUE INDEX IF NOT EXISTS idx_unit_config_org_type_unique
ON public.unit_configurations(organization_id, lower(unit_type_name));

-- Add unit_type column to units table
ALTER TABLE public.units ADD COLUMN IF NOT EXISTS unit_type TEXT;

-- Normalize and de-duplicate existing unit numbers before enforcing uniqueness.
-- Keeps the first occurrence unchanged and appends a short id suffix to duplicates.
UPDATE public.units
SET unit_number = upper(btrim(unit_number))
WHERE unit_number IS NOT NULL;

UPDATE public.units
SET unit_number = 'UNIT-' || left(id::text, 8)
WHERE unit_number IS NULL OR btrim(unit_number) = '';

WITH ranked_units AS (
  SELECT
    id,
    property_id,
    unit_number,
    row_number() OVER (
      PARTITION BY property_id, lower(unit_number)
      ORDER BY id
    ) AS rn
  FROM public.units
), duplicates AS (
  SELECT
    id,
    unit_number || '-' || left(id::text, 6) AS deduped_unit_number
  FROM ranked_units
  WHERE rn > 1
)
UPDATE public.units u
SET unit_number = d.deduped_unit_number
FROM duplicates d
WHERE u.id = d.id;

-- Enforce unique unit identifier per property (A1 cannot repeat in the same plot)
CREATE UNIQUE INDEX IF NOT EXISTS idx_units_property_unit_number_unique
ON public.units(property_id, lower(unit_number));

ALTER TABLE public.units
  DROP CONSTRAINT IF EXISTS units_unit_number_format_check;

ALTER TABLE public.units
  ADD CONSTRAINT units_unit_number_format_check
  CHECK (unit_number ~ '^A[0-9]{1,3}$')
  NOT VALID;

-- Create index on organization_id for faster queries
CREATE INDEX IF NOT EXISTS idx_unit_configurations_organization_id
ON public.unit_configurations(organization_id);

-- RLS Policies for unit_configurations
ALTER TABLE public.unit_configurations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their organization's unit configurations"
  ON public.unit_configurations;

DROP POLICY IF EXISTS "Users can create unit configurations for their organization"
  ON public.unit_configurations;

DROP POLICY IF EXISTS "Users can update their organization's unit configurations"
  ON public.unit_configurations;

DROP POLICY IF EXISTS "Users can delete their organization's unit configurations"
  ON public.unit_configurations;

-- Allow users to view their organization's configurations
CREATE POLICY "Users can view their organization's unit configurations"
  ON public.unit_configurations
  FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM public.profiles 
      WHERE id = auth.uid()
    )
  );

-- Allow users to insert configurations for their organization
CREATE POLICY "Users can create unit configurations for their organization"
  ON public.unit_configurations
  FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM public.profiles 
      WHERE id = auth.uid()
    )
  );

-- Allow users to update their organization's configurations
CREATE POLICY "Users can update their organization's unit configurations"
  ON public.unit_configurations
  FOR UPDATE
  USING (
    organization_id IN (
      SELECT organization_id FROM public.profiles 
      WHERE id = auth.uid()
    )
  )
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM public.profiles 
      WHERE id = auth.uid()
    )
  );

-- Allow users to delete their organization's configurations
CREATE POLICY "Users can delete their organization's unit configurations"
  ON public.unit_configurations
  FOR DELETE
  USING (
    organization_id IN (
      SELECT organization_id FROM public.profiles 
      WHERE id = auth.uid()
    )
  );
