create table if not exists public.document_workflow_documents (
  id uuid primary key default gen_random_uuid(),
  registration_number text not null unique,
  title text not null,
  document_type text not null,
  author_name text not null,
  author_iin bigint not null,
  status text not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.document_workflow_route_steps (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.document_workflow_documents(id) on delete cascade,
  step_number integer not null,
  action_type text not null,
  assignee_user_id uuid,
  assignee_name text not null,
  assignee_iin bigint not null,
  status text not null default 'pending',
  due_date date,
  completed_at timestamptz,
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (document_id, step_number)
);

create index if not exists document_workflow_route_steps_document_id_idx
  on public.document_workflow_route_steps(document_id);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists document_workflow_documents_set_updated_at
  on public.document_workflow_documents;
create trigger document_workflow_documents_set_updated_at
before update on public.document_workflow_documents
for each row execute function public.set_updated_at();

drop trigger if exists document_workflow_route_steps_set_updated_at
  on public.document_workflow_route_steps;
create trigger document_workflow_route_steps_set_updated_at
before update on public.document_workflow_route_steps
for each row execute function public.set_updated_at();

alter table public.document_workflow_documents enable row level security;
alter table public.document_workflow_route_steps enable row level security;

drop policy if exists "Authenticated users can manage workflow documents"
  on public.document_workflow_documents;
create policy "Authenticated users can manage workflow documents"
on public.document_workflow_documents
for all
to authenticated
using (true)
with check (true);

drop policy if exists "Authenticated users can manage workflow route steps"
  on public.document_workflow_route_steps;
create policy "Authenticated users can manage workflow route steps"
on public.document_workflow_route_steps
for all
to authenticated
using (true)
with check (true);
