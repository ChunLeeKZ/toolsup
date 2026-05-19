create table if not exists public.organizations (
  bin text primary key,
  short_name text not null,
  full_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (bin ~ '^[0-9]{12}$')
);

alter table public.organizations enable row level security;

drop policy if exists "Authenticated users can read organizations"
  on public.organizations;
create policy "Authenticated users can read organizations"
on public.organizations
for select
to authenticated
using (true);

drop policy if exists "Authenticated users can manage organizations"
  on public.organizations;

create table if not exists public.app_user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text not null,
  iin bigint not null,
  organization_bin text,
  organization_name text,
  photo_bucket text,
  photo_path text,
  photo_mime_type text,
  photo_uploaded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.app_user_profiles
  add column if not exists organization_bin text,
  add column if not exists organization_name text;

create index if not exists app_user_profiles_organization_bin_idx
  on public.app_user_profiles(organization_bin);

alter table public.app_user_profiles enable row level security;

drop policy if exists "Authenticated users can read user profiles"
  on public.app_user_profiles;
create policy "Authenticated users can read user profiles"
on public.app_user_profiles
for select
to authenticated
using (true);

drop policy if exists "Users can create own profile"
  on public.app_user_profiles;
create policy "Users can create own profile"
on public.app_user_profiles
for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "Users can update own profile"
  on public.app_user_profiles;
create policy "Users can update own profile"
on public.app_user_profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
