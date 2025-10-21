-- Track progress of operation stages
-- Safe to run multiple times

alter table if exists public.operation_stages
  add column if not exists started_at timestamptz,
  add column if not exists finished_at timestamptz,
  add column if not exists is_current boolean default false;

-- Helpful partial index for current stage per operation
create index if not exists idx_operation_stages_current
  on public.operation_stages(operation_id)
  where is_current;
