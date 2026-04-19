-- ============================================================
-- SQL Migration: Update Checkout RPC for Outlet Routing
-- Run this in the Supabase SQL Editor
-- ============================================================

-- First, drop the old signature to prevent ambiguous function call errors
DROP FUNCTION IF EXISTS public.process_checkout(JSONB, TEXT, UUID);

-- Create the updated function with the p_outlet_id parameter
CREATE OR REPLACE FUNCTION public.process_checkout(
    p_cart_items     JSONB,       -- [{ "product_id": uuid, "quantity": int, "price": numeric }]
    p_payment_method TEXT,        -- 'CASH' | 'BANK_TRANSFER' | 'QRIS' etc.
    p_staff_id       UUID,
    p_outlet_id      UUID         -- NEW: Outlet scoping
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_transaction_id  UUID;
    v_journal_id      UUID;
    v_reference_no    TEXT;
    v_total_amount    NUMERIC(15,2) := 0;
    v_total_cogs      NUMERIC(15,2) := 0;
    v_item            JSONB;
    v_product         RECORD;
    v_stock           INTEGER;
    v_cash_id         UUID;
    v_inventory_id    UUID;
    v_revenue_id      UUID;
    v_cogs_id         UUID;
    v_items_out       JSONB := '[]'::JSONB;
BEGIN
    -- ========================================================
    -- 0. INPUT VALIDATION
    -- ========================================================
    IF p_cart_items IS NULL OR jsonb_array_length(p_cart_items) = 0 THEN
        RAISE EXCEPTION 'cart_items cannot be empty';
    END IF;

    IF p_outlet_id IS NULL THEN
        RAISE EXCEPTION 'outlet_id cannot be null';
    END IF;

    -- ========================================================
    -- 1. VALIDATE STOCK & CALCULATE TOTALS
    -- ========================================================
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_cart_items)
    LOOP
        -- Get product info
        SELECT id, name, sku, purchase_price, selling_price
        INTO v_product
        FROM public.products
        WHERE id = (v_item->>'product_id')::UUID;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product not found: %', v_item->>'product_id';
        END IF;

        -- Get stock for THIS outlet (lock row for update)
        SELECT current_stock INTO v_stock
        FROM public.product_stock
        WHERE product_id = (v_item->>'product_id')::UUID
          AND outlet_id = p_outlet_id
        FOR UPDATE;

        IF v_stock IS NULL THEN
            -- No stock record means 0 stock
            v_stock := 0;
        END IF;

        IF v_stock < (v_item->>'quantity')::INT THEN
            RAISE EXCEPTION 'Insufficient stock for "%" (SKU: %) at outlet. Available: %, Requested: %',
                v_product.name,
                v_product.sku,
                v_stock,
                (v_item->>'quantity')::INT;
        END IF;

        v_total_amount := v_total_amount
            + ( (v_item->>'quantity')::INT * (v_item->>'price')::NUMERIC );

        v_total_cogs := v_total_cogs
            + ( (v_item->>'quantity')::INT * v_product.purchase_price );
    END LOOP;

    -- ========================================================
    -- 2. GENERATE REFERENCE NUMBER  (INV-YYYYMMDD-XXXXX)
    -- ========================================================
    v_reference_no := 'INV-'
        || to_char(now(), 'YYYYMMDD') || '-'
        || lpad(nextval('invoice_seq')::TEXT, 5, '0');

    -- ========================================================
    -- 3. INSERT TRANSACTION HEADER
    -- ========================================================
    INSERT INTO public.transactions (
        transaction_type, transaction_date, reference_no,
        total_amount, notes, created_by, outlet_id
    ) VALUES (
        'SALE', now(), v_reference_no,
        v_total_amount,
        'Payment: ' || COALESCE(p_payment_method, 'CASH'),
        p_staff_id,
        p_outlet_id
    ) RETURNING id INTO v_transaction_id;

    -- ========================================================
    -- 4. INSERT TRANSACTION ITEMS & DECREMENT STOCK
    -- ========================================================
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_cart_items)
    LOOP
        INSERT INTO public.transaction_items (
            transaction_id, product_id, quantity, unit_price
        ) VALUES (
            v_transaction_id,
            (v_item->>'product_id')::UUID,
            (v_item->>'quantity')::INT,
            (v_item->>'price')::NUMERIC
        );

        -- Decrement stock locally for this outlet
        UPDATE public.product_stock
        SET current_stock = current_stock - (v_item->>'quantity')::INT,
            updated_at    = now()
        WHERE product_id = (v_item->>'product_id')::UUID
          AND outlet_id = p_outlet_id;

        -- Build response items
        SELECT v_items_out || jsonb_build_object(
            'product_id',  v_item->>'product_id',
            'product_name',(SELECT name FROM public.products WHERE id = (v_item->>'product_id')::UUID),
            'quantity',    (v_item->>'quantity')::INT,
            'unit_price',  (v_item->>'price')::NUMERIC,
            'subtotal',    (v_item->>'quantity')::INT * (v_item->>'price')::NUMERIC
        ) INTO v_items_out;
    END LOOP;

    -- ========================================================
    -- 5. ACCOUNTING ENGINE — Journal + Ledger
    -- ========================================================
    -- Resolve account IDs
    SELECT id INTO v_cash_id      FROM public.accounts WHERE code = '1-1001';
    SELECT id INTO v_inventory_id FROM public.accounts WHERE code = '1-1002';
    SELECT id INTO v_revenue_id   FROM public.accounts WHERE code = '4-4001';
    SELECT id INTO v_cogs_id      FROM public.accounts WHERE code = '5-5001';

    -- Journal Header
    INSERT INTO public.journal_entries (
        transaction_id, entry_date, description, outlet_id
    ) VALUES (
        v_transaction_id, now(),
        'POS Checkout — ' || v_reference_no || ' | ' || p_payment_method,
        p_outlet_id
    ) RETURNING id INTO v_journal_id;

    -- Ledger Line 1: DR Cash / CR Revenue
    INSERT INTO public.ledger_entries (journal_entry_id, account_id, debit, credit)
    VALUES
        (v_journal_id, v_cash_id,    v_total_amount, 0),
        (v_journal_id, v_revenue_id, 0,              v_total_amount);

    -- Ledger Line 2: DR COGS / CR Inventory (at purchase cost)
    IF v_total_cogs > 0 THEN
        INSERT INTO public.ledger_entries (journal_entry_id, account_id, debit, credit)
        VALUES
            (v_journal_id, v_cogs_id,      v_total_cogs, 0),
            (v_journal_id, v_inventory_id,  0,            v_total_cogs);
    END IF;

    -- ========================================================
    -- 6. RETURN RESULT
    -- ========================================================
    RETURN jsonb_build_object(
        'success',        TRUE,
        'transaction_id', v_transaction_id,
        'reference_no',   v_reference_no,
        'total_amount',   v_total_amount,
        'total_cogs',     v_total_cogs,
        'payment_method', p_payment_method,
        'items',          v_items_out,
        'journal_id',     v_journal_id,
        'created_at',     now()
    );
END;
$$;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
