-- ============================================================
-- RLS PATCH: Allow anon role for MVP testing
-- Run this in the Supabase SQL Editor
-- ============================================================
-- This replaces and extends fix_rls_anon.sql with INSERT
-- policies for journal_entries and ledger_entries, needed
-- because the process_checkout RPC runs as SECURITY DEFINER
-- but the Edge Function uses the service_role key.
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- Drop existing anon policies to avoid conflicts
-- ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Categories: full access for anon" ON public.categories;
DROP POLICY IF EXISTS "Products: full access for anon" ON public.products;
DROP POLICY IF EXISTS "Transactions: read for anon" ON public.transactions;
DROP POLICY IF EXISTS "Transactions: insert for anon" ON public.transactions;
DROP POLICY IF EXISTS "Transaction Items: read for anon" ON public.transaction_items;
DROP POLICY IF EXISTS "Transaction Items: insert for anon" ON public.transaction_items;
DROP POLICY IF EXISTS "Accounts: read for anon" ON public.accounts;
DROP POLICY IF EXISTS "Journal Entries: read for anon" ON public.journal_entries;
DROP POLICY IF EXISTS "Journal Entries: insert for anon" ON public.journal_entries;
DROP POLICY IF EXISTS "Ledger Entries: read for anon" ON public.ledger_entries;
DROP POLICY IF EXISTS "Ledger Entries: insert for anon" ON public.ledger_entries;
DROP POLICY IF EXISTS "Profiles: read for anon" ON public.profiles;

-- ──────────────────────────────────────────────────────────
-- PROFILES: anon can read (for staff name lookups)
-- ──────────────────────────────────────────────────────────
CREATE POLICY "Profiles: read for anon"
    ON public.profiles FOR SELECT
    TO anon
    USING (TRUE);

-- ──────────────────────────────────────────────────────────
-- CATEGORIES: anon full access
-- ──────────────────────────────────────────────────────────
CREATE POLICY "Categories: full access for anon"
    ON public.categories FOR ALL
    TO anon
    USING (TRUE)
    WITH CHECK (TRUE);

-- ──────────────────────────────────────────────────────────
-- PRODUCTS: anon full access
-- ──────────────────────────────────────────────────────────
CREATE POLICY "Products: full access for anon"
    ON public.products FOR ALL
    TO anon
    USING (TRUE)
    WITH CHECK (TRUE);

-- ──────────────────────────────────────────────────────────
-- ACCOUNTS: anon can read
-- ──────────────────────────────────────────────────────────
CREATE POLICY "Accounts: read for anon"
    ON public.accounts FOR SELECT
    TO anon
    USING (TRUE);

-- ──────────────────────────────────────────────────────────
-- TRANSACTIONS: anon can SELECT + INSERT
-- ──────────────────────────────────────────────────────────
CREATE POLICY "Transactions: read for anon"
    ON public.transactions FOR SELECT
    TO anon
    USING (TRUE);

CREATE POLICY "Transactions: insert for anon"
    ON public.transactions FOR INSERT
    TO anon
    WITH CHECK (TRUE);

-- ──────────────────────────────────────────────────────────
-- TRANSACTION ITEMS: anon can SELECT + INSERT
-- ──────────────────────────────────────────────────────────
CREATE POLICY "Transaction Items: read for anon"
    ON public.transaction_items FOR SELECT
    TO anon
    USING (TRUE);

CREATE POLICY "Transaction Items: insert for anon"
    ON public.transaction_items FOR INSERT
    TO anon
    WITH CHECK (TRUE);

-- ──────────────────────────────────────────────────────────
-- JOURNAL ENTRIES: anon can SELECT + INSERT  ← NEW
-- ──────────────────────────────────────────────────────────
CREATE POLICY "Journal Entries: read for anon"
    ON public.journal_entries FOR SELECT
    TO anon
    USING (TRUE);

CREATE POLICY "Journal Entries: insert for anon"
    ON public.journal_entries FOR INSERT
    TO anon
    WITH CHECK (TRUE);

-- ──────────────────────────────────────────────────────────
-- LEDGER ENTRIES: anon can SELECT + INSERT  ← NEW
-- ──────────────────────────────────────────────────────────
CREATE POLICY "Ledger Entries: read for anon"
    ON public.ledger_entries FOR SELECT
    TO anon
    USING (TRUE);

CREATE POLICY "Ledger Entries: insert for anon"
    ON public.ledger_entries FOR INSERT
    TO anon
    WITH CHECK (TRUE);

-- ============================================================
-- DONE ✅ — Run this ONCE in the Supabase SQL Editor.
-- Anonymous checkouts use created_by = NULL (no dummy profile
-- needed since profiles.id FK references auth.users).
-- ============================================================
