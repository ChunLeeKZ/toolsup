alter table public.app_user_profiles
  add column if not exists photo_bucket text,
  add column if not exists photo_path text,
  add column if not exists photo_mime_type text,
  add column if not exists photo_uploaded_at timestamptz;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'user-profile-photos',
  'user-profile-photos',
  false,
  10485760,
  array[
    'image/png',
    'image/jpeg',
    'application/octet-stream'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Authenticated users can read profile photos"
  on storage.objects;
create policy "Authenticated users can read profile photos"
on storage.objects
for select
to authenticated
using (bucket_id = 'user-profile-photos');

drop policy if exists "Users can upload own profile photo"
  on storage.objects;
create policy "Users can upload own profile photo"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'user-profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can update own profile photo"
  on storage.objects;
create policy "Users can update own profile photo"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'user-profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'user-profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can delete own profile photo"
  on storage.objects;
create policy "Users can delete own profile photo"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'user-profile-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);
