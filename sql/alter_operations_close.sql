-- Add closing fields to operations to lock after finish
-- Safe to run multiple times

alter table if exists public.operations
  add column if not exists is_closed boolean default false,
  add column if not exists closed_at timestamptz;
