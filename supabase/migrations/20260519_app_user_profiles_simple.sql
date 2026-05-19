create table if not exists public.app_user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text not null,
  iin bigint not null,
  photo_bucket text,
  photo_path text,
  photo_mime_type text,
  photo_uploaded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop index if exists public.app_user_profiles_iin_idx;

create index if not exists app_user_profiles_iin_idx
  on public.app_user_profiles(iin);

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

insert into public.app_user_profiles (
  id,
  email,
  display_name,
  iin
)
select
  users.id,
  users.email,
  coalesce(
    nullif(users.raw_user_meta_data ->> 'display_name', ''),
    users.email
  ),
  (users.raw_user_meta_data ->> 'iin')::bigint
from auth.users as users
where coalesce(users.raw_user_meta_data ->> 'iin', '') ~ '^[0-9]{12}$'
  and users.email is not null
on conflict (id) do update
set
  email = excluded.email,
  display_name = excluded.display_name,
  iin = excluded.iin;

do $$
begin
  if to_regclass('public.document_workflow_route_steps') is not null then
    alter table public.document_workflow_route_steps
      add column if not exists assignee_user_id uuid;
  end if;
end;
$$;
