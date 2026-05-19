create table if not exists public.organizations (
  bin text primary key,
  short_name text not null,
  full_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (bin ~ '^[0-9]{12}$')
);

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

update public.app_user_profiles
set
  organization_bin = null,
  organization_name = null
where organization_bin is not null
  and organization_bin !~ '^[0-9]{12}$';

insert into public.organizations (
  bin,
  short_name,
  full_name
)
select distinct
  profile.organization_bin,
  coalesce(nullif(profile.organization_name, ''), profile.organization_bin),
  coalesce(nullif(profile.organization_name, ''), profile.organization_bin)
from public.app_user_profiles as profile
where profile.organization_bin is not null
on conflict (bin) do update
set
  short_name = excluded.short_name,
  full_name = excluded.full_name;

alter table public.app_user_profiles
  drop constraint if exists app_user_profiles_organization_bin_fkey;

alter table public.app_user_profiles
  add constraint app_user_profiles_organization_bin_fkey
  foreign key (organization_bin)
  references public.organizations(bin)
  on update cascade
  on delete set null;

update public.app_user_profiles as profile
set organization_name = organization.short_name
from public.organizations as organization
where profile.organization_bin = organization.bin;
