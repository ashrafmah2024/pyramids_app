-- Disable auto-adding stage 'شراء من مورد' for ANY operation.
-- This script will drop the trigger (if exists) and make the function a no-op.

create or replace function public.ensure_commercial_purchase_stage()
returns trigger
language plpgsql
as $$
DECLARE
  -- No state needed; function is now a no-op
BEGIN
  RETURN NEW;
END;
$$;

-- Remove the trigger so no auto-linking happens
DROP TRIGGER IF EXISTS trg_ensure_commercial_purchase_stage ON purchases;
