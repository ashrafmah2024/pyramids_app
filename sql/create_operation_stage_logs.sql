-- Create unified logs table for stage movements: receive/deliver/waste/expense
-- Safe to run multiple times

create table if not exists public.operation_stage_logs (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null references public.operations(id) on delete cascade,
  stage_id uuid not null references public.manufacturing_stages(id) on delete restrict,
  order_no int not null,
  log_type text not null check (log_type in ('receive','deliver','waste','expense')),
  qty numeric(18,6),
  amount numeric(18,2),
  unit_id int references public.units(id),
  note text,
  created_at timestamptz not null default now(),
  created_by uuid
);

create index if not exists idx_osl_op_stage_order on public.operation_stage_logs(operation_id, stage_id, order_no);
create index if not exists idx_osl_op_created on public.operation_stage_logs(operation_id, created_at desc);
