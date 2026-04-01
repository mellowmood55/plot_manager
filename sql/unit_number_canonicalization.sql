-- Canonicalize unit_number values and enforce integrity rules.
-- Canonical format: A + 1..3 digits, with 1-digit values padded to 2 digits.
-- Examples: 'a 1' -> 'A01', 'A9' -> 'A09', 'a123' -> 'A123'

BEGIN;

ALTER TABLE public.units
  DROP CONSTRAINT IF EXISTS units_unit_number_format_check;

-- Step 1: Canonicalize existing unit numbers where possible.
UPDATE public.units
SET unit_number =
  CASE
    WHEN regexp_replace(upper(coalesce(unit_number, '')), '[^0-9]', '', 'g') = ''
      THEN NULL
    ELSE 'A' || lpad(
      regexp_replace(upper(coalesce(unit_number, '')), '[^0-9]', '', 'g'),
      2,
      '0'
    )
  END;

-- Step 2: Fill missing/invalid values with generated canonical values per property.
DO $$
DECLARE
  rec RECORD;
  candidate_number INTEGER;
  candidate_unit TEXT;
BEGIN
  FOR rec IN
    SELECT id, property_id
    FROM public.units
    WHERE unit_number IS NULL
  LOOP
    candidate_number := 1;

    LOOP
      IF candidate_number > 999 THEN
        RAISE EXCEPTION 'Unable to assign canonical unit number for unit % in property % (exceeded A999).', rec.id, rec.property_id;
      END IF;

      candidate_unit := 'A' || lpad(candidate_number::text, 2, '0');

      IF NOT EXISTS (
        SELECT 1
        FROM public.units u
        WHERE u.property_id = rec.property_id
          AND lower(u.unit_number) = lower(candidate_unit)
          AND u.id <> rec.id
      ) THEN
        UPDATE public.units
        SET unit_number = candidate_unit
        WHERE id = rec.id;
        EXIT;
      END IF;

      candidate_number := candidate_number + 1;
    END LOOP;
  END LOOP;
END $$;

-- Step 3: Resolve duplicates created by canonicalization.
DO $$
DECLARE
  dup RECORD;
  candidate_number INTEGER;
  candidate_unit TEXT;
BEGIN
  FOR dup IN
    WITH ranked AS (
      SELECT
        id,
        property_id,
        unit_number,
        row_number() OVER (
          PARTITION BY property_id, lower(unit_number)
          ORDER BY id
        ) AS rn
      FROM public.units
    )
    SELECT id, property_id
    FROM ranked
    WHERE rn > 1
  LOOP
    candidate_number := 1;

    LOOP
      IF candidate_number > 999 THEN
        RAISE EXCEPTION 'Unable to reassign duplicate unit % in property % (exceeded A999).', dup.id, dup.property_id;
      END IF;

      candidate_unit := 'A' || lpad(candidate_number::text, 2, '0');

      IF NOT EXISTS (
        SELECT 1
        FROM public.units u
        WHERE u.property_id = dup.property_id
          AND lower(u.unit_number) = lower(candidate_unit)
          AND u.id <> dup.id
      ) THEN
        UPDATE public.units
        SET unit_number = candidate_unit
        WHERE id = dup.id;
        EXIT;
      END IF;

      candidate_number := candidate_number + 1;
    END LOOP;
  END LOOP;
END $$;

-- Step 4: Add and validate strict format constraint.
ALTER TABLE public.units
  ADD CONSTRAINT units_unit_number_format_check
  CHECK (unit_number ~ '^A[0-9]{1,3}$') NOT VALID;

ALTER TABLE public.units
  VALIDATE CONSTRAINT units_unit_number_format_check;

-- Step 5: Recreate unique index on canonicalized values.
DROP INDEX IF EXISTS public.idx_units_property_unit_number_unique;

CREATE UNIQUE INDEX idx_units_property_unit_number_unique
ON public.units(property_id, lower(unit_number));

COMMIT;
