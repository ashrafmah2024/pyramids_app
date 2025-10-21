-- Prepare operation_stages for ordered manufacturing stages per operation
-- Safe to run multiple times

-- Ensure key columns exist with proper FKs
alter table if exists public.operation_stages
  add column if not exists operation_id uuid references public.operations(id) on delete cascade;

alter table if exists public.operation_stages
  add column if not exists stage_id uuid references public.manufacturing_stages(id) on delete restrict;

-- Ensure order_no exists
alter table if exists public.operation_stages
  add column if not exists order_no int;

-- Backfill nulls to 0 for existing rows (optional)
update public.operation_stages set order_no = coalesce(order_no, 0) where order_no is null;

-- Add unique constraint to avoid duplicate stage per operation
alter table if exists public.operation_stages drop constraint if exists uq_operation_stages_operation_stage;
alter table if exists public.operation_stages
  add constraint uq_operation_stages_operation_stage unique (operation_id, stage_id);

-- Helpful indexes
create index if not exists idx_operation_stages_operation_order on public.operation_stages(operation_id, order_no);
create index if not exists idx_operation_stages_stage on public.operation_stages(stage_id);
