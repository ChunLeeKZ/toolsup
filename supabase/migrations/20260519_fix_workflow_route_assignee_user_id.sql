alter table public.document_workflow_route_steps
  add column if not exists assignee_user_id uuid;

create index if not exists document_workflow_route_steps_assignee_user_id_idx
  on public.document_workflow_route_steps(assignee_user_id);

do $$
begin
  if to_regclass('public.app_user_profiles') is not null then
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

    update public.document_workflow_route_steps as route_step
    set assignee_user_id = profile.id
    from public.app_user_profiles as profile
    where route_step.assignee_user_id is null
      and route_step.assignee_iin = profile.iin;
  end if;
end;
$$;
