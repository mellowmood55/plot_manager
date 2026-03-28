-- Maintenance & Repair Tracker Schema
-- Supabase RLS policies ensure landlords can only manage requests for units in their organization

-- Create enums for priority and status
CREATE TYPE maintenance_priority AS ENUM ('low', 'medium', 'high');
CREATE TYPE maintenance_status AS ENUM ('open', 'in_progress', 'completed', 'closed');

-- Create maintenance_requests table
CREATE TABLE public.maintenance_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  priority maintenance_priority NOT NULL DEFAULT 'medium',
  status maintenance_status NOT NULL DEFAULT 'open',
  estimated_cost DECIMAL(10, 2),
  actual_cost DECIMAL(10, 2),
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index for common queries
CREATE INDEX idx_maintenance_requests_unit_id ON public.maintenance_requests(unit_id);
CREATE INDEX idx_maintenance_requests_status ON public.maintenance_requests(status);
CREATE INDEX idx_maintenance_requests_created_at ON public.maintenance_requests(created_at DESC);

-- Enable RLS
ALTER TABLE public.maintenance_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Landlords can only view/manage requests for units in their organization
-- Join path: maintenance_requests.unit_id -> units.id -> properties.id -> organizations.id
-- Organizations.created_by stores the landlord's auth user ID
CREATE POLICY "Select maintenance requests - landlord organization access"
  ON public.maintenance_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.units u
        INNER JOIN public.properties p ON u.property_id = p.id
        INNER JOIN public.organizations o ON p.organization_id = o.id
      WHERE u.id = maintenance_requests.unit_id
        AND o.created_by = auth.uid()
    )
  );

CREATE POLICY "Insert maintenance requests - landlord organization access"
  ON public.maintenance_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.units u
        INNER JOIN public.properties p ON u.property_id = p.id
        INNER JOIN public.organizations o ON p.organization_id = o.id
      WHERE u.id = unit_id
        AND o.created_by = auth.uid()
    )
  );

CREATE POLICY "Update maintenance requests - landlord organization access"
  ON public.maintenance_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.units u
        INNER JOIN public.properties p ON u.property_id = p.id
        INNER JOIN public.organizations o ON p.organization_id = o.id
      WHERE u.id = maintenance_requests.unit_id
        AND o.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.units u
        INNER JOIN public.properties p ON u.property_id = p.id
        INNER JOIN public.organizations o ON p.organization_id = o.id
      WHERE u.id = unit_id
        AND o.created_by = auth.uid()
    )
  );

CREATE POLICY "Delete maintenance requests - landlord organization access"
  ON public.maintenance_requests
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.units u
        INNER JOIN public.properties p ON u.property_id = p.id
        INNER JOIN public.organizations o ON p.organization_id = o.id
      WHERE u.id = maintenance_requests.unit_id
        AND o.created_by = auth.uid()
    )
  );

-- Create Supabase Storage bucket for maintenance attachments
-- Note: Execute this in Supabase Dashboard > Storage > New Bucket
-- Bucket Name: maintenance_attachments
-- Public: false (to enforce RLS)

-- Example RLS policy for Storage (apply in Supabase Storage settings):
-- Policy: Allow landlords to access their organization's maintenance attachments
-- This leverages the maintenance_requests.image_url path to verify organization ownership
