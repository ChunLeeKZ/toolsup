create table if not exists public.inventory_documents (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  document_number integer not null unique,
  inventory_completed boolean not null default false,
  uploaded_to_1c boolean not null default false,
  inventory_officer text not null,
  inventory_officer_iin bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fixed_assets (
  id text primary key,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_document_lines (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.inventory_documents(id) on delete cascade,
  line_number integer not null,
  fixed_asset_id text not null references public.fixed_assets(id),
  fixed_asset_name text not null,
  inventory_number text not null,
  exists_in_accounting boolean not null default true,
  physically_available boolean not null default false,
  scanned_at timestamptz,
  raw_barcode_value text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (document_id, line_number),
  unique (document_id, inventory_number)
);

create index if not exists inventory_document_lines_document_id_idx
  on public.inventory_document_lines(document_id);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists inventory_documents_set_updated_at
  on public.inventory_documents;
create trigger inventory_documents_set_updated_at
before update on public.inventory_documents
for each row execute function public.set_updated_at();

drop trigger if exists fixed_assets_set_updated_at
  on public.fixed_assets;
create trigger fixed_assets_set_updated_at
before update on public.fixed_assets
for each row execute function public.set_updated_at();

drop trigger if exists inventory_document_lines_set_updated_at
  on public.inventory_document_lines;
create trigger inventory_document_lines_set_updated_at
before update on public.inventory_document_lines
for each row execute function public.set_updated_at();

alter table public.inventory_documents enable row level security;
alter table public.fixed_assets enable row level security;
alter table public.inventory_document_lines enable row level security;

drop policy if exists "Authenticated users can manage inventory documents"
  on public.inventory_documents;
create policy "Authenticated users can manage inventory documents"
on public.inventory_documents
for all
to authenticated
using (true)
with check (true);

drop policy if exists "Authenticated users can manage fixed assets"
  on public.fixed_assets;
create policy "Authenticated users can manage fixed assets"
on public.fixed_assets
for all
to authenticated
using (true)
with check (true);

drop policy if exists "Authenticated users can manage inventory document lines"
  on public.inventory_document_lines;
create policy "Authenticated users can manage inventory document lines"
on public.inventory_document_lines
for all
to authenticated
using (true)
with check (true);

insert into public.inventory_documents (
  id,
  date,
  document_number,
  inventory_completed,
  uploaded_to_1c,
  inventory_officer,
  inventory_officer_iin
)
values
  (
    '00000000-0000-0000-0000-000000001001',
    '2026-05-09',
    1001,
    false,
    false,
    'Касымов Ерлан',
    860101300123
  ),
  (
    '00000000-0000-0000-0000-000000001002',
    '2026-05-07',
    1002,
    true,
    false,
    'Ахметова Дина',
    910215450678
  ),
  (
    '00000000-0000-0000-0000-000000001003',
    '2026-05-03',
    1003,
    true,
    true,
    'Серикбаев Нурлан',
    800930350456
  )
on conflict (document_number) do update
set
  date = excluded.date,
  inventory_completed = public.inventory_documents.inventory_completed,
  uploaded_to_1c = public.inventory_documents.uploaded_to_1c,
  inventory_officer = excluded.inventory_officer,
  inventory_officer_iin = excluded.inventory_officer_iin;

insert into public.fixed_assets (id, name)
values
  ('fa-001', 'Ноутбук Lenovo ThinkPad'),
  ('fa-002', 'Принтер HP LaserJet'),
  ('fa-003', 'Монитор Dell 24'),
  ('fa-004', 'Сервер Dell PowerEdge'),
  ('fa-005', 'Шкаф телекоммуникационный')
on conflict (id) do update
set name = excluded.name;

insert into public.inventory_document_lines (
  id,
  document_id,
  line_number,
  fixed_asset_id,
  fixed_asset_name,
  inventory_number,
  exists_in_accounting,
  physically_available
)
select
  source.id::uuid,
  document.id,
  source.line_number,
  source.fixed_asset_id,
  source.fixed_asset_name,
  source.inventory_number,
  source.exists_in_accounting,
  source.physically_available
from (
  values
    (
      '00000000-0000-0000-0001-000000001001',
      1001,
      1,
      'fa-001',
      'Ноутбук Lenovo ThinkPad',
      'INV-000124',
      true,
      true
    ),
    (
      '00000000-0000-0000-0001-000000001002',
      1001,
      2,
      'fa-002',
      'Принтер HP LaserJet',
      'INV-000219',
      true,
      false
    ),
    (
      '00000000-0000-0000-0001-000000001003',
      1002,
      1,
      'fa-003',
      'Монитор Dell 24',
      'INV-000301',
      true,
      true
    ),
    (
      '00000000-0000-0000-0001-000000001004',
      1003,
      1,
      'fa-004',
      'Сервер Dell PowerEdge',
      'INV-000410',
      true,
      true
    ),
    (
      '00000000-0000-0000-0001-000000001005',
      1003,
      2,
      'fa-005',
      'Шкаф телекоммуникационный',
      'INV-000411',
      true,
      true
    )
) as source (
  id,
  document_number,
  line_number,
  fixed_asset_id,
  fixed_asset_name,
  inventory_number,
  exists_in_accounting,
  physically_available
)
join public.inventory_documents as document
  on document.document_number = source.document_number
on conflict (document_id, line_number) do update
set
  fixed_asset_id = excluded.fixed_asset_id,
  fixed_asset_name = excluded.fixed_asset_name,
  inventory_number = excluded.inventory_number,
  exists_in_accounting = excluded.exists_in_accounting,
  physically_available =
    public.inventory_document_lines.physically_available
    or excluded.physically_available;
