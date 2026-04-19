-- ============================================================
-- SQL Migration: Global Products & Per-Outlet Data
-- Run this in the Supabase SQL Editor
-- ============================================================

-- 1. Create product_stock to track stock per outlet
CREATE TABLE IF NOT EXISTS public.product_stock (
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    current_stock INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (product_id, outlet_id)
);

-- RLS for product_stock
ALTER TABLE public.product_stock ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'product_stock' AND policyname = 'Product Stock: full access for authenticated') THEN
    CREATE POLICY "Product Stock: full access for authenticated" ON public.product_stock FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'product_stock' AND policyname = 'Product Stock: full access for anon') THEN
    CREATE POLICY "Product Stock: full access for anon" ON public.product_stock FOR ALL TO anon USING (TRUE) WITH CHECK (TRUE);
  END IF;
END $$;

-- Trigger for updated_at
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_product_stock_updated_at') THEN
        CREATE TRIGGER trg_product_stock_updated_at
            BEFORE UPDATE ON public.product_stock
            FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
    END IF;
END $$;

-- 2. Migrate existing current_stock from products to product_stock for 'Main Store'
DO $$
DECLARE
  v_main_outlet_id UUID;
BEGIN
  -- Get the main store outlet (the first one)
  SELECT id INTO v_main_outlet_id FROM public.outlets ORDER BY created_at ASC LIMIT 1;
  
  IF v_main_outlet_id IS NOT NULL THEN
    -- Only migrate if product_stock is currently empty
    IF NOT EXISTS (SELECT 1 FROM public.product_stock LIMIT 1) THEN
        -- Check if current_stock still exists on products before migrating
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='current_stock') THEN
            EXECUTE 'INSERT INTO public.product_stock (product_id, outlet_id, current_stock) SELECT id, $1, current_stock FROM public.products' USING v_main_outlet_id;
        END IF;
    END IF;
  END IF;
END $$;

-- 3. Remove current_stock from products
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='products' AND column_name='current_stock') THEN
        DROP TRIGGER IF EXISTS trg_update_stock ON public.transaction_items;
        DROP FUNCTION IF EXISTS public.fn_update_product_stock();
        ALTER TABLE public.products DROP COLUMN current_stock;
    END IF;
END $$;

-- 4. Add outlet_id to transactions and journal_entries
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE;
ALTER TABLE public.journal_entries ADD COLUMN IF NOT EXISTS outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE;

-- 5. Update existing transactions/journals to point to the main store to avoid orphaned data
DO $$
DECLARE
  v_main_outlet_id UUID;
BEGIN
  SELECT id INTO v_main_outlet_id FROM public.outlets ORDER BY created_at ASC LIMIT 1;
  
  IF v_main_outlet_id IS NOT NULL THEN
    UPDATE public.transactions SET outlet_id = v_main_outlet_id WHERE outlet_id IS NULL;
    UPDATE public.journal_entries SET outlet_id = v_main_outlet_id WHERE outlet_id IS NULL;
  END IF;
END $$;

-- 6. Create View for Products with Stock
CREATE OR REPLACE VIEW public.vw_products_with_stock AS
SELECT 
    p.id,
    p.sku,
    p.name,
    p.category_id,
    p.image_url,
    p.purchase_price,
    p.selling_price,
    p.unit,
    p.is_active,
    p.created_at,
    o.id AS outlet_id,
    COALESCE(s.current_stock, 0) as current_stock
FROM public.products p
CROSS JOIN public.outlets o
LEFT JOIN public.product_stock s ON s.product_id = p.id AND s.outlet_id = o.id;

GRANT SELECT ON public.vw_products_with_stock TO authenticated, anon;


-- 7. Update RPC insert_expense to accept outlet_id
CREATE OR REPLACE FUNCTION public.insert_expense(
    p_description   TEXT,
    p_amount        NUMERIC,
    p_expense_acc   UUID,
    p_cash_acc      UUID,
    p_staff_id      UUID,
    p_outlet_id     UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_journal_id UUID;
BEGIN
    -- 1. Input Validation
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than 0';
    END IF;
    
    IF p_outlet_id IS NULL THEN
        RAISE EXCEPTION 'outlet_id must not be null';
    END IF;

    -- 2. Create Journal Entry
    INSERT INTO public.journal_entries (
        transaction_id, entry_date, description, outlet_id
    ) VALUES (
        NULL, now(), 'EXPENSE: ' || p_description, p_outlet_id
    ) RETURNING id INTO v_journal_id;

    -- 3. Create Ledger Entries (Debit Expense, Credit Cash)
    -- Ledger Line 1: DR Expense
    INSERT INTO public.ledger_entries (journal_entry_id, account_id, debit, credit)
    VALUES (v_journal_id, p_expense_acc, p_amount, 0);

    -- Ledger Line 2: CR Cash
    INSERT INTO public.ledger_entries (journal_entry_id, account_id, debit, credit)
    VALUES (v_journal_id, p_cash_acc, 0, p_amount);

    RETURN jsonb_build_object(
        'success', TRUE,
        'journal_id', v_journal_id,
        'description', p_description,
        'amount', p_amount
    );
END;
$$;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
