-- Add manufacturer_id to operation_stages (optional link to a manufacturer per stage)
alter table operation_stages
  add column if not exists manufacturer_id uuid null
  references manufacturers(id) on update cascade on delete set null;

-- Create manufacturer_transactions to record payables and payments
create table if not exists manufacturer_transactions (
  id uuid primary key default gen_random_uuid(),
  manufacturer_id uuid not null references manufacturers(id) on update cascade on delete restrict,
  operation_id uuid null references operations(id) on update cascade on delete restrict,
  stage_id uuid null references manufacturing_stages(id) on update cascade on delete restrict,
  amount numeric(18,2) not null,
  direction text not null check (direction in ('debit','credit')),
  currency text not null default 'EGP',
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_mtran_manufacturer on manufacturer_transactions(manufacturer_id, created_at desc);
create index if not exists idx_mtran_operation on manufacturer_transactions(operation_id);
create index if not exists idx_mtran_stage on manufacturer_transactions(stage_id);
