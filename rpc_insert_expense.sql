-- ============================================================
-- RPC: insert_expense
-- Atomic double-entry insertion for operational expenses.
-- ============================================================

CREATE OR REPLACE FUNCTION public.insert_expense(
    p_description   TEXT,
    p_amount        NUMERIC,
    p_expense_acc   UUID,
    p_cash_acc      UUID,
    p_staff_id      UUID
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

    -- 2. Create Journal Entry
    INSERT INTO public.journal_entries (
        transaction_id, entry_date, description
    ) VALUES (
        NULL, now(), 'EXPENSE: ' || p_description
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
