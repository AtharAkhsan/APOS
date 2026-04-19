-- ============================================================
-- QRIS SCHEMA PATCH (V2)
-- Run this in the Supabase SQL Editor
-- ============================================================

DO $$ 
BEGIN
  -- Add "status" column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name='transactions' AND column_name='status'
  ) THEN
    ALTER TABLE public.transactions ADD COLUMN status TEXT DEFAULT 'PAID';
  END IF;

  -- Add "payment_method" column (previously stored only in 'notes')
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name='transactions' AND column_name='payment_method'
  ) THEN
    ALTER TABLE public.transactions ADD COLUMN payment_method TEXT DEFAULT 'CASH';
  END IF;

  -- Make sure reference_no doesn't block inserts if missing
  -- Only do this if it's currently NOT NULL without a default
  ALTER TABLE public.transactions ALTER COLUMN reference_no DROP NOT NULL;
END $$;

-- Force Supabase PostgREST Data API to reload its schema cache
NOTIFY pgrst, 'reload schema';
