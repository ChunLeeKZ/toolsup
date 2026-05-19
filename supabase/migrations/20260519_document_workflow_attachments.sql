create table if not exists public.document_workflow_attachments (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null
    references public.document_workflow_documents(id)
    on delete cascade,
  file_name text not null,
  storage_bucket text not null default 'workflow-documents',
  storage_path text not null,
  mime_type text,
  size_bytes integer not null default 0,
  uploaded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);

create index if not exists document_workflow_attachments_document_id_idx
  on public.document_workflow_attachments(document_id);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists document_workflow_attachments_set_updated_at
  on public.document_workflow_attachments;
create trigger document_workflow_attachments_set_updated_at
before update on public.document_workflow_attachments
for each row execute function public.set_updated_at();

alter table public.document_workflow_attachments enable row level security;

drop policy if exists "Authenticated users can manage workflow attachments"
  on public.document_workflow_attachments;
create policy "Authenticated users can manage workflow attachments"
on public.document_workflow_attachments
for all
to authenticated
using (true)
with check (true);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'workflow-documents',
  'workflow-documents',
  false,
  52428800,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
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

drop policy if exists "Authenticated users can upload workflow files"
  on storage.objects;
create policy "Authenticated users can upload workflow files"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'workflow-documents');

drop policy if exists "Authenticated users can read workflow files"
  on storage.objects;
create policy "Authenticated users can read workflow files"
on storage.objects
for select
to authenticated
using (bucket_id = 'workflow-documents');

drop policy if exists "Authenticated users can update workflow files"
  on storage.objects;
create policy "Authenticated users can update workflow files"
on storage.objects
for update
to authenticated
using (bucket_id = 'workflow-documents')
with check (bucket_id = 'workflow-documents');

drop policy if exists "Authenticated users can delete workflow files"
  on storage.objects;
create policy "Authenticated users can delete workflow files"
on storage.objects
for delete
to authenticated
using (bucket_id = 'workflow-documents');
