-- Supabase schema for operations sales (Option A) and client transactions
-- Safe to run multiple times (IF NOT EXISTS used where possible)

-- 1) Operations: add sale-related columns
alter table if exists public.operations
  add column if not exists sale_price numeric,
  add column if not exists sale_currency text not null default 'EGP',
  add column if not exists sale_date timestamptz,
  add column if not exists sale_posted boolean not null default false,
  add column if not exists sale_posted_by uuid,
  add column if not exists sale_posted_at timestamptz;

-- Optional helpful index for sale_date queries
create index if not exists idx_operations_sale_date on public.operations(sale_date);

-- 2) Client transactions ledger (do not mutate client balance directly)
create table if not exists public.client_transactions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  operation_id uuid references public.operations(id) on delete set null,
  amount numeric not null,
  direction text not null check (direction in ('debit','credit')),
  currency text not null default 'EGP',
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid(),
  notes text
);

create index if not exists idx_client_tx_client on public.client_transactions(client_id);
create index if not exists idx_client_tx_operation on public.client_transactions(operation_id);
create index if not exists idx_client_tx_created_at on public.client_transactions(created_at);

-- 3) View for client balances (calculated on the fly)
create or replace view public.client_balances as
select
  c.id as client_id,
  coalesce(sum(case when t.direction = 'debit' then t.amount else -t.amount end), 0) as balance
from public.clients c
left join public.client_transactions t on t.client_id = c.id
group by c.id;

-- 4) RLS policies (read for all authenticated; insert/update by record owner)
alter table public.client_transactions enable row level security;

-- SELECT policy: all authenticated users can read
drop policy if exists client_tx_select_all on public.client_transactions;
create policy client_tx_select_all on public.client_transactions
for select using (auth.role() = 'authenticated');

-- INSERT policy: only the creator can insert their own rows
drop policy if exists client_tx_insert_owner on public.client_transactions;
create policy client_tx_insert_owner on public.client_transactions
for insert with check (created_by = auth.uid());

-- UPDATE policy: only the creator can update their own rows
drop policy if exists client_tx_update_owner on public.client_transactions;
create policy client_tx_update_owner on public.client_transactions
for update using (created_by = auth.uid())
          with check (created_by = auth.uid());

-- 5) Helper trigger to auto-update updated_at on operations (if function exists create it)
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end; $$;

drop trigger if exists trg_operations_updated_at on public.operations;
create trigger trg_operations_updated_at
before update on public.operations
for each row execute function public.set_updated_at();
