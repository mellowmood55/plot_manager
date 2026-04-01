-- Phase 4 (Financials): payments table with landlord-scoped RLS policies

CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id UUID NOT NULL REFERENCES public.units(id) ON DELETE CASCADE,
  tenant_id UUID REFERENCES public.tenants(id) ON DELETE SET NULL,
  amount_paid NUMERIC(12, 2) NOT NULL CHECK (amount_paid > 0),
  transaction_ref TEXT,
  payment_method TEXT NOT NULL,
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_unit_id ON public.payments(unit_id);
CREATE INDEX IF NOT EXISTS idx_payments_tenant_id ON public.payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON public.payments(payment_date);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Landlords can view payments for owned units" ON public.payments;
DROP POLICY IF EXISTS "Landlords can insert payments for owned units" ON public.payments;
DROP POLICY IF EXISTS "Landlords can update payments for owned units" ON public.payments;
DROP POLICY IF EXISTS "Landlords can delete payments for owned units" ON public.payments;

-- A landlord can access payments only when the payment's unit belongs to a property
-- in the same organization as the authenticated profile.
CREATE POLICY "Landlords can view payments for owned units"
  ON public.payments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.units u
      JOIN public.properties p ON p.id = u.property_id
      JOIN public.profiles pr ON pr.organization_id = p.organization_id
      WHERE u.id = payments.unit_id
        AND pr.id = auth.uid()
    )
  );

CREATE POLICY "Landlords can insert payments for owned units"
  ON public.payments
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.units u
      JOIN public.properties p ON p.id = u.property_id
      JOIN public.profiles pr ON pr.organization_id = p.organization_id
      WHERE u.id = payments.unit_id
        AND pr.id = auth.uid()
    )
  );

CREATE POLICY "Landlords can update payments for owned units"
  ON public.payments
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.units u
      JOIN public.properties p ON p.id = u.property_id
      JOIN public.profiles pr ON pr.organization_id = p.organization_id
      WHERE u.id = payments.unit_id
        AND pr.id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.units u
      JOIN public.properties p ON p.id = u.property_id
      JOIN public.profiles pr ON pr.organization_id = p.organization_id
      WHERE u.id = payments.unit_id
        AND pr.id = auth.uid()
    )
  );

CREATE POLICY "Landlords can delete payments for owned units"
  ON public.payments
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public.units u
      JOIN public.properties p ON p.id = u.property_id
      JOIN public.profiles pr ON pr.organization_id = p.organization_id
      WHERE u.id = payments.unit_id
        AND pr.id = auth.uid()
    )
  );
