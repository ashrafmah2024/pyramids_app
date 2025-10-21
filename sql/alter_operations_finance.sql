-- Finance fields for operations: indirect expense, sale price, waste unit purchase cost
-- Safe to run multiple times

alter table if exists public.operations
  add column if not exists indirect_expense numeric default 0,
  add column if not exists sale_price numeric default 0,
  add column if not exists waste_unit_cost_purchase numeric default 0;
