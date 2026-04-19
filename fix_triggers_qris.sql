-- ============================================================
-- FIX: PREVENT PREMATURE STOCK DEDUCTION & JOURNALING FOR PENDING QRIS
-- ============================================================
-- The triggers "trg_update_stock" and "trg_create_journal" were blindly
-- firing on any INSERT. For QRIS payments, the status is initially "PENDING"
-- and the webhook resolves the stock and journal later. Thus, the automatic
-- triggers MUST ignore PENDING transactions.
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_update_product_stock()
RETURNS TRIGGER AS $$
DECLARE
    v_txn_type TEXT;
    v_status TEXT;
BEGIN
    -- Determine the transaction type AND status from the parent row
    SELECT transaction_type, COALESCE(status, 'PAID') INTO v_txn_type, v_status
    FROM public.transactions
    WHERE id = NEW.transaction_id;

    -- ONLY deduct automatically if the transaction is fully PAID or purely CASH at creation.
    -- If it is PENDING, we bypass this and let the webhook trigger the deduction manually later.
    IF v_status = 'PENDING' THEN
        RETURN NEW;
    END IF;

    IF v_txn_type = 'SALE' THEN
        UPDATE public.products
        SET current_stock = current_stock - NEW.quantity,
            updated_at    = now()
        WHERE id = NEW.product_id;
    ELSIF v_txn_type = 'PURCHASE' THEN
        UPDATE public.products
        SET current_stock = current_stock + NEW.quantity,
            updated_at    = now()
        WHERE id = NEW.product_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION public.fn_create_journal_for_transaction()
RETURNS TRIGGER AS $$
DECLARE
    v_journal_id   UUID;
    v_cash_id      UUID;
    v_inventory_id UUID;
    v_revenue_id   UUID;
    v_cogs_id      UUID;
    v_purchase_exp UUID;
    v_total_cost   NUMERIC(15,2);
BEGIN
    -- ONLY generate an automatic journal entry if the status is NOT PENDING.
    -- (The webhook handles journaling manually when a PENDING clears).
    IF COALESCE(NEW.status, 'PAID') = 'PENDING' THEN
        RETURN NEW;
    END IF;

    -- Resolve account IDs
    SELECT id INTO v_cash_id      FROM public.accounts WHERE code = '1-1001';
    SELECT id INTO v_inventory_id FROM public.accounts WHERE code = '1-1002';
    SELECT id INTO v_revenue_id   FROM public.accounts WHERE code = '4-4001';
    SELECT id INTO v_cogs_id      FROM public.accounts WHERE code = '5-5001';
    SELECT id INTO v_purchase_exp FROM public.accounts WHERE code = '5-5002';

    IF NEW.transaction_type = 'SALE' THEN
        INSERT INTO public.journal_entries (transaction_id, entry_date, description)
        VALUES (NEW.id, NEW.transaction_date,
                'Auto journal — SALE ' || COALESCE(NEW.reference_no, NEW.id::TEXT))
        RETURNING id INTO v_journal_id;

        INSERT INTO public.ledger_entries (journal_entry_id, account_id, debit, credit)
        VALUES
            (v_journal_id, v_cash_id,    NEW.total_amount, 0),
            (v_journal_id, v_revenue_id, 0, NEW.total_amount);

        SELECT COALESCE(SUM(ti.quantity * p.purchase_price), 0)
        INTO v_total_cost
        FROM public.transaction_items ti
        JOIN public.products p ON p.id = ti.product_id
        WHERE ti.transaction_id = NEW.id;

        IF v_total_cost > 0 THEN
            INSERT INTO public.ledger_entries (journal_entry_id, account_id, debit, credit)
            VALUES
                (v_journal_id, v_cogs_id,      v_total_cost, 0),
                (v_journal_id, v_inventory_id, 0, v_total_cost);
        END IF;

    ELSIF NEW.transaction_type = 'PURCHASE' THEN
        INSERT INTO public.journal_entries (transaction_id, entry_date, description)
        VALUES (NEW.id, NEW.transaction_date,
                'Auto journal — PURCHASE ' || COALESCE(NEW.reference_no, NEW.id::TEXT))
        RETURNING id INTO v_journal_id;

        INSERT INTO public.ledger_entries (journal_entry_id, account_id, debit, credit)
        VALUES
            (v_journal_id, v_inventory_id, NEW.total_amount, 0),
            (v_journal_id, v_cash_id,      0, NEW.total_amount);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reload schema caches just in case
NOTIFY pgrst, 'reload schema';
