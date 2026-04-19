-- ============================================================
-- POS & ACCOUNTING SYSTEM — MVP DATABASE SCHEMA
-- Platform   : Supabase (PostgreSQL)
-- Version    : 1.0.0
-- Description: Sales, Purchasing, Inventory & Double-Entry
--              Accounting with automatic journal generation.
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. PROFILES (linked to Supabase Auth)
-- ============================================================
CREATE TABLE public.profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name   TEXT        NOT NULL,
    role        TEXT        NOT NULL DEFAULT 'cashier'
                            CHECK (role IN ('owner', 'admin', 'cashier')),
    avatar_url  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'User / staff profiles linked to Supabase Auth.';

-- ============================================================
-- 2. CATEGORIES
-- ============================================================
CREATE TABLE public.categories (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.categories IS 'Product categories.';

-- ============================================================
-- 3. PRODUCTS
-- ============================================================
CREATE TABLE public.products (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id     UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    sku             TEXT NOT NULL UNIQUE,
    name            TEXT NOT NULL,
    description     TEXT,
    purchase_price  NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (purchase_price >= 0),
    selling_price   NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (selling_price >= 0),
    current_stock   INTEGER       NOT NULL DEFAULT 0,
    unit            TEXT NOT NULL DEFAULT 'pcs',
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.products IS 'Product master with SKU, prices, and live stock count.';

-- ============================================================
-- 4. TRANSACTIONS (header — SALE or PURCHASE)
-- ============================================================
CREATE TABLE public.transactions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('SALE', 'PURCHASE')),
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    reference_no    TEXT,
    total_amount    NUMERIC(15,2) NOT NULL DEFAULT 0,
    notes           TEXT,
    created_by      UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.transactions IS 'Transaction header for both sales (Penjualan) and purchases (Pembelian).';

-- ============================================================
-- 5. TRANSACTION ITEMS (line items)
-- ============================================================
CREATE TABLE public.transaction_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id  UUID NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
    product_id      UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity        INTEGER       NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(15,2) NOT NULL CHECK (unit_price >= 0),
    subtotal        NUMERIC(15,2) NOT NULL GENERATED ALWAYS AS (quantity * unit_price) STORED,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.transaction_items IS 'Line items belonging to a transaction.';

-- ============================================================
-- 6. ACCOUNTS (Chart of Accounts)
-- ============================================================
CREATE TABLE public.accounts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code            TEXT NOT NULL UNIQUE,
    name            TEXT NOT NULL,
    account_type    TEXT NOT NULL CHECK (account_type IN (
                        'ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'
                    )),
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.accounts IS 'Chart of Accounts for double-entry bookkeeping.';

-- Seed default accounts
INSERT INTO public.accounts (code, name, account_type, description) VALUES
    ('1-1001', 'Kas / Cash',           'ASSET',    'Kas utama perusahaan'),
    ('1-1002', 'Persediaan / Inventory','ASSET',    'Nilai persediaan barang'),
    ('2-2001', 'Hutang Usaha / AP',     'LIABILITY','Accounts Payable'),
    ('3-3001', 'Modal Pemilik / Equity', 'EQUITY',   'Owner equity'),
    ('4-4001', 'Pendapatan Penjualan',  'REVENUE',  'Revenue from sales'),
    ('5-5001', 'Harga Pokok Penjualan / COGS', 'EXPENSE', 'Cost of Goods Sold'),
    ('5-5002', 'Beban Pembelian',       'EXPENSE',  'Purchase expense');

-- ============================================================
-- 7. JOURNAL ENTRIES
-- ============================================================
CREATE TABLE public.journal_entries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id  UUID REFERENCES public.transactions(id) ON DELETE CASCADE,
    entry_date      TIMESTAMPTZ NOT NULL DEFAULT now(),
    description     TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.journal_entries IS 'Journal entry headers — the accounting heart of the system.';

-- ============================================================
-- 8. LEDGER ENTRIES (debits & credits)
-- ============================================================
CREATE TABLE public.ledger_entries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    journal_entry_id UUID NOT NULL REFERENCES public.journal_entries(id) ON DELETE CASCADE,
    account_id      UUID NOT NULL REFERENCES public.accounts(id) ON DELETE RESTRICT,
    debit           NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (debit  >= 0),
    credit          NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Each row must be either a debit OR a credit, not both
    CONSTRAINT chk_debit_or_credit CHECK (
        (debit > 0 AND credit = 0) OR (debit = 0 AND credit > 0)
    )
);

COMMENT ON TABLE public.ledger_entries IS 'Individual debit/credit lines within a journal entry.';

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_products_category      ON public.products(category_id);
CREATE INDEX idx_products_sku           ON public.products(sku);
CREATE INDEX idx_transactions_type      ON public.transactions(transaction_type);
CREATE INDEX idx_transactions_date      ON public.transactions(transaction_date);
CREATE INDEX idx_transaction_items_txn  ON public.transaction_items(transaction_id);
CREATE INDEX idx_journal_entries_txn    ON public.journal_entries(transaction_id);
CREATE INDEX idx_ledger_entries_journal ON public.ledger_entries(journal_entry_id);
CREATE INDEX idx_ledger_entries_account ON public.ledger_entries(account_id);


-- ============================================================
-- FUNCTION: Update product stock on transaction item insert
-- ============================================================
-- SALE  → decrease stock
-- PURCHASE → increase stock
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_update_product_stock()
RETURNS TRIGGER AS $$
DECLARE
    v_txn_type TEXT;
BEGIN
    -- Determine the transaction type from the parent row
    SELECT transaction_type INTO v_txn_type
    FROM public.transactions
    WHERE id = NEW.transaction_id;

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

CREATE TRIGGER trg_update_stock
    AFTER INSERT ON public.transaction_items
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_product_stock();


-- ============================================================
-- FUNCTION: Auto-create journal + ledger entries on transaction
-- ============================================================
-- SALE journal:
--   DR  Cash            (total_amount)
--   CR  Revenue         (total_amount)
--   DR  COGS            (cost)
--   CR  Inventory       (cost)
--
-- PURCHASE journal:
--   DR  Inventory       (total_amount)
--   CR  Cash            (total_amount)
-- ============================================================
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
    -- Resolve account IDs
    SELECT id INTO v_cash_id      FROM public.accounts WHERE code = '1-1001';
    SELECT id INTO v_inventory_id FROM public.accounts WHERE code = '1-1002';
    SELECT id INTO v_revenue_id   FROM public.accounts WHERE code = '4-4001';
    SELECT id INTO v_cogs_id      FROM public.accounts WHERE code = '5-5001';
    SELECT id INTO v_purchase_exp FROM public.accounts WHERE code = '5-5002';

    IF NEW.transaction_type = 'SALE' THEN
        -- ---- Journal Header ----
        INSERT INTO public.journal_entries (transaction_id, entry_date, description)
        VALUES (NEW.id, NEW.transaction_date,
                'Auto journal — SALE ' || COALESCE(NEW.reference_no, NEW.id::TEXT))
        RETURNING id INTO v_journal_id;

        -- ---- Ledger: DR Cash / CR Revenue ----
        INSERT INTO public.ledger_entries (journal_entry_id, account_id, debit, credit)
        VALUES
            (v_journal_id, v_cash_id,    NEW.total_amount, 0),
            (v_journal_id, v_revenue_id, 0, NEW.total_amount);

        -- ---- Ledger: DR COGS / CR Inventory (at cost) ----
        SELECT COALESCE(SUM(ti.quantity * p.purchase_price), 0)
        INTO v_total_cost
        FROM public.transaction_items ti
        JOIN public.products p ON p.id = ti.product_id
        WHERE ti.transaction_id = NEW.id;

        IF v_total_cost > 0 THEN
            INSERT INTO public.ledger_entries (journal_entry_id, account_id, debit, credit)
            VALUES
                (v_journal_id, v_cogs_id,      v_total_cost, 0),
                (v_journal_id, v_inventory_id,  0, v_total_cost);
        END IF;

    ELSIF NEW.transaction_type = 'PURCHASE' THEN
        -- ---- Journal Header ----
        INSERT INTO public.journal_entries (transaction_id, entry_date, description)
        VALUES (NEW.id, NEW.transaction_date,
                'Auto journal — PURCHASE ' || COALESCE(NEW.reference_no, NEW.id::TEXT))
        RETURNING id INTO v_journal_id;

        -- ---- Ledger: DR Inventory / CR Cash ----
        INSERT INTO public.ledger_entries (journal_entry_id, account_id, debit, credit)
        VALUES
            (v_journal_id, v_inventory_id, NEW.total_amount, 0),
            (v_journal_id, v_cash_id,      0, NEW.total_amount);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_create_journal
    AFTER INSERT ON public.transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_create_journal_for_transaction();


-- ============================================================
-- FUNCTION: Auto-create profile on user sign-up
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unnamed User')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_handle_new_user();


-- ============================================================
-- FUNCTION: Keep updated_at current
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();


-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries    ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------
-- PROFILES
-- -------------------------------------------------------
-- Users can read all profiles (team visibility)
CREATE POLICY "Profiles: read for authenticated"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (TRUE);

-- Users can update only their own profile
CREATE POLICY "Profiles: update own"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- -------------------------------------------------------
-- CATEGORIES  (all authenticated can CRUD)
-- -------------------------------------------------------
CREATE POLICY "Categories: full access for authenticated"
    ON public.categories FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- -------------------------------------------------------
-- PRODUCTS  (all authenticated can CRUD)
-- -------------------------------------------------------
CREATE POLICY "Products: full access for authenticated"
    ON public.products FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- -------------------------------------------------------
-- TRANSACTIONS  (all authenticated can read; creator can insert)
-- -------------------------------------------------------
CREATE POLICY "Transactions: read for authenticated"
    ON public.transactions FOR SELECT
    TO authenticated
    USING (TRUE);

CREATE POLICY "Transactions: insert for authenticated"
    ON public.transactions FOR INSERT
    TO authenticated
    WITH CHECK (TRUE);

-- -------------------------------------------------------
-- TRANSACTION ITEMS
-- -------------------------------------------------------
CREATE POLICY "Transaction Items: read for authenticated"
    ON public.transaction_items FOR SELECT
    TO authenticated
    USING (TRUE);

CREATE POLICY "Transaction Items: insert for authenticated"
    ON public.transaction_items FOR INSERT
    TO authenticated
    WITH CHECK (TRUE);

-- -------------------------------------------------------
-- ACCOUNTS  (read-only for non-owners; full for owner/admin)
-- -------------------------------------------------------
CREATE POLICY "Accounts: read for authenticated"
    ON public.accounts FOR SELECT
    TO authenticated
    USING (TRUE);

CREATE POLICY "Accounts: manage for owner/admin"
    ON public.accounts FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role IN ('owner', 'admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role IN ('owner', 'admin')
        )
    );

-- -------------------------------------------------------
-- JOURNAL ENTRIES (read-only for all; system-managed via triggers)
-- -------------------------------------------------------
CREATE POLICY "Journal Entries: read for authenticated"
    ON public.journal_entries FOR SELECT
    TO authenticated
    USING (TRUE);

-- -------------------------------------------------------
-- LEDGER ENTRIES (read-only for all; system-managed via triggers)
-- -------------------------------------------------------
CREATE POLICY "Ledger Entries: read for authenticated"
    ON public.ledger_entries FOR SELECT
    TO authenticated
    USING (TRUE);


-- ============================================================
-- DONE 🎉
-- Paste this entire script into the Supabase SQL Editor and run.
-- ============================================================
