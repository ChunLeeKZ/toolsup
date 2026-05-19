create table if not exists public.document_workflow_documents (
  id uuid primary key default gen_random_uuid(),
  registration_number text not null unique,
  title text not null,
  document_type text not null,
  author_name text not null,
  author_iin bigint not null,
  status text not null default 'draft'
    check (status in ('draft', 'in_route', 'completed', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.document_workflow_route_steps (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null
    references public.document_workflow_documents(id)
    on delete cascade,
  step_number integer not null,
  action_type text not null
    check (action_type in (
      'approval',
      'signing',
      'review',
      'familiarization'
    )),
  assignee_user_id uuid,
  assignee_name text not null,
  assignee_iin bigint not null,
  status text not null default 'pending'
    check (status in ('pending', 'in_progress', 'completed', 'rejected')),
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

insert into public.document_workflow_documents (
  id,
  registration_number,
  title,
  document_type,
  author_name,
  author_iin,
  status,
  created_at
)
values
  (
    '00000000-0000-0002-0000-000000000001',
    'DOC-2026-001',
    'Акт инвентаризации основных средств',
    'Акт',
    'Касымов Ерлан',
    860101300123,
    'in_route',
    '2026-05-18 09:30:00+06'
  ),
  (
    '00000000-0000-0002-0000-000000000002',
    'DOC-2026-002',
    'Приказ о проведении инвентаризации',
    'Приказ',
    'Ахметова Дина',
    910215450678,
    'completed',
    '2026-05-17 15:00:00+06'
  )
on conflict (registration_number) do update
set
  title = excluded.title,
  document_type = excluded.document_type,
  author_name = excluded.author_name,
  author_iin = excluded.author_iin,
  status = public.document_workflow_documents.status;

insert into public.document_workflow_route_steps (
  id,
  document_id,
  step_number,
  action_type,
  assignee_name,
  assignee_iin,
  status,
  due_date,
  completed_at,
  comment
)
select
  source.id::uuid,
  document.id,
  source.step_number,
  source.action_type,
  source.assignee_name,
  source.assignee_iin,
  source.status,
  source.due_date::date,
  source.completed_at::timestamptz,
  source.comment
from (
  values
    (
      '00000000-0000-0002-0001-000000000001',
      'DOC-2026-001',
      1,
      'review',
      'Ахметова Дина',
      910215450678,
      'completed',
      '2026-05-18',
      '2026-05-18 10:15:00+06',
      'Рассмотрено без замечаний'
    ),
    (
      '00000000-0000-0002-0001-000000000002',
      'DOC-2026-001',
      2,
      'approval',
      'Серикбаев Нурлан',
      800930350456,
      'in_progress',
      '2026-05-19',
      null,
      null
    ),
    (
      '00000000-0000-0002-0001-000000000003',
      'DOC-2026-001',
      3,
      'signing',
      'Директор организации',
      770101300789,
      'pending',
      '2026-05-20',
      null,
      null
    ),
    (
      '00000000-0000-0002-0001-000000000004',
      'DOC-2026-002',
      1,
      'approval',
      'Касымов Ерлан',
      860101300123,
      'completed',
      null,
      '2026-05-17 16:00:00+06',
      null
    ),
    (
      '00000000-0000-0002-0001-000000000005',
      'DOC-2026-002',
      2,
      'familiarization',
      'Материально ответственное лицо',
      850315301111,
      'completed',
      null,
      '2026-05-17 17:00:00+06',
      null
    )
) as source (
  id,
  registration_number,
  step_number,
  action_type,
  assignee_name,
  assignee_iin,
  status,
  due_date,
  completed_at,
  comment
)
join public.document_workflow_documents as document
  on document.registration_number = source.registration_number
on conflict (document_id, step_number) do update
set
  action_type = excluded.action_type,
  assignee_name = excluded.assignee_name,
  assignee_iin = excluded.assignee_iin,
  status = public.document_workflow_route_steps.status,
  due_date = excluded.due_date,
  completed_at = public.document_workflow_route_steps.completed_at,
  comment = coalesce(public.document_workflow_route_steps.comment, excluded.comment);
