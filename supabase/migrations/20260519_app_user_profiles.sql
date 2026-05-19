create table if not exists public.app_user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text not null,
  iin bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists app_user_profiles_iin_idx
  on public.app_user_profiles(iin);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists app_user_profiles_set_updated_at
  on public.app_user_profiles;
create trigger app_user_profiles_set_updated_at
before update on public.app_user_profiles
for each row execute function public.set_updated_at();

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
where coalesce(users.raw_user_meta_data ->> 'iin', '') ~ '^\d{12}$'
on conflict (id) do update
set
  email = excluded.email,
  display_name = excluded.display_name,
  iin = excluded.iin;

create or replace function public.handle_new_user_profile()
returns trigger
security definer
set search_path = public
as $$
declare
  user_iin text;
begin
  user_iin := new.raw_user_meta_data ->> 'iin';

  if user_iin is null or user_iin !~ '^\d{12}$' then
    return new;
  end if;

  insert into public.app_user_profiles (
    id,
    email,
    display_name,
    iin
  )
  values (
    new.id,
    new.email,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      new.email
    ),
    user_iin::bigint
  )
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = excluded.display_name,
    iin = excluded.iin;

  return new;
end;
$$ language plpgsql;

drop trigger if exists on_auth_user_created_profile
  on auth.users;
create trigger on_auth_user_created_profile
after insert or update on auth.users
for each row execute function public.handle_new_user_profile();

do $$
begin
  if to_regclass('public.document_workflow_route_steps') is not null then
    alter table public.document_workflow_route_steps
      add column if not exists assignee_user_id uuid;

    if not exists (
      select 1
      from pg_constraint
      where conname = 'document_workflow_route_steps_assignee_user_id_fkey'
    ) then
      alter table public.document_workflow_route_steps
        add constraint document_workflow_route_steps_assignee_user_id_fkey
        foreign key (assignee_user_id)
        references public.app_user_profiles(id)
        on delete set null;
    end if;

    create index if not exists document_workflow_route_steps_assignee_user_id_idx
      on public.document_workflow_route_steps(assignee_user_id);

    update public.document_workflow_route_steps as route_step
    set assignee_user_id = profile.id
    from public.app_user_profiles as profile
    where route_step.assignee_user_id is null
      and route_step.assignee_iin = profile.iin;
  end if;
end;
$$;
