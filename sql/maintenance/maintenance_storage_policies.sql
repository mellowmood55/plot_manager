-- Supabase Storage RLS policies for maintenance_attachments bucket
-- IMPORTANT: Ensure the bucket name matches exactly: maintenance_attachments
-- Run this in Supabase Dashboard SQL Editor as project admin (postgres role).
-- Do not run this through the client app connection (anon/authenticated role).

-- Create bucket (idempotent)
insert into storage.buckets (id, name, public)
values ('maintenance_attachments', 'maintenance_attachments', true)
on conflict (id) do nothing;

-- Policy 1 (INSERT): allow authenticated uploads to maintenance_attachments
drop policy if exists "maintenance_attachments_insert_authenticated" on storage.objects;
create policy "maintenance_attachments_insert_authenticated"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'maintenance_attachments'
  and auth.uid() is not null
);

-- Policy 2 (SELECT): public read access for instant image loading
-- If privacy is a priority, replace "to public" with "to authenticated"
drop policy if exists "maintenance_attachments_select_public" on storage.objects;
create policy "maintenance_attachments_select_public"
on storage.objects
for select
to public
using (bucket_id = 'maintenance_attachments');

-- Policy 3 (DELETE): users can delete their own uploads
drop policy if exists "maintenance_attachments_delete_own" on storage.objects;
create policy "maintenance_attachments_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'maintenance_attachments'
  and owner = auth.uid()
);
