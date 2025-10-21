-- Add agreement fields and references for single-item agreement per operation
-- Safe to run multiple times

-- Ensure unit_id matches public.units(id) type (bigint)
alter table if exists public.operations drop column if exists unit_id;

alter table if exists public.operations
  add column if not exists unit_id bigint references public.units(id) on delete restrict,
  add column if not exists product_type_id uuid references public.business_fields(id) on delete restrict,
  add column if not exists agreement_qty numeric,
  add column if not exists agreement_unit_price numeric,
  add column if not exists agreement_total numeric,
  add column if not exists description text;

-- Planned delivery date (delivery_date) separate from actual sale/delivery date (sale_date)
alter table if exists public.operations
  add column if not exists delivery_date timestamptz;

-- Helpful indexes for lookups
create index if not exists idx_operations_unit_id on public.operations(unit_id);
create index if not exists idx_operations_product_type_id on public.operations(product_type_id);

-- Optional: simple check constraints (can be relaxed if needed)
-- Constraints: Postgres doesn't support IF NOT EXISTS here; use drop/create
alter table if exists public.operations drop constraint if exists chk_operations_agreement_qty_nonneg;
alter table if exists public.operations add constraint chk_operations_agreement_qty_nonneg
  check (agreement_qty is null or agreement_qty >= 0);

alter table if exists public.operations drop constraint if exists chk_operations_agreement_unit_price_nonneg;
alter table if exists public.operations add constraint chk_operations_agreement_unit_price_nonneg
  check (agreement_unit_price is null or agreement_unit_price >= 0);

alter table if exists public.operations drop constraint if exists chk_operations_agreement_total_nonneg;
alter table if exists public.operations add constraint chk_operations_agreement_total_nonneg
  check (agreement_total is null or agreement_total >= 0);
