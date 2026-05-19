alter table if exists public.app_user_profiles
  drop constraint if exists app_user_profiles_iin_idx;

drop index if exists public.app_user_profiles_iin_idx;

create index if not exists app_user_profiles_iin_idx
  on public.app_user_profiles(iin);
