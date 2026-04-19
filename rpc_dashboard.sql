-- ============================================================
-- ANALYTICS & OUTLETS SCHEMA PATCH
-- Run this in your Supabase SQL Editor
-- ============================================================

-- 1. Create Outlets Table
CREATE TABLE IF NOT EXISTS public.outlets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Note: The user already ran 'ALTER TABLE transactions ADD COLUMN outlet_id UUID;'
-- So we just safely add the foreign key constraint.
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name='fk_transactions_outlet'
  ) THEN
    ALTER TABLE public.transactions 
    ADD CONSTRAINT fk_transactions_outlet 
    FOREIGN KEY (outlet_id) REFERENCES public.outlets(id);
  END IF;
END $$;

-- 2. Seed Mock Outlets if empty
DO $$
DECLARE
    v_kemang_id UUID;
    v_sudirman_id UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.outlets) THEN
        INSERT INTO public.outlets (name, address) VALUES 
        ('Outlet Kemang', 'Jl. Kemang Raya No.1')
        RETURNING id INTO v_kemang_id;

        INSERT INTO public.outlets (name, address) VALUES 
        ('Outlet Sudirman', 'Gedung Sudirman Lt.5')
        RETURNING id INTO v_sudirman_id;
        
        -- To make past transactions visible in the dashboard initially, 
        -- we assign all existing NULL outlet transactions to the first outlet.
        UPDATE public.transactions SET outlet_id = v_kemang_id WHERE outlet_id IS NULL;
    END IF;
END $$;


-- 3. The Central Analytics RPC
-- Receives 'daily', 'monthly', or 'yearly'.
-- Receives an optional p_outlet_id.
CREATE OR REPLACE FUNCTION public.get_dashboard_metrics(
    p_period TEXT,
    p_outlet_id UUID DEFAULT NULL
) 
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_start_date TIMESTAMPTZ;
    v_end_date TIMESTAMPTZ;
    v_sales NUMERIC(15,2) := 0;
    v_cogs NUMERIC(15,2) := 0;
    v_txn_count INT := 0;
    v_trend JSONB := '[]'::JSONB;
    v_tz TEXT := 'Asia/Jakarta';
BEGIN
    -- Determine Date Range based on period (in local timezone)
    IF p_period = 'daily' THEN
        v_start_date := date_trunc('day', now() AT TIME ZONE v_tz) AT TIME ZONE v_tz;
        v_end_date := v_start_date + interval '1 day';
    ELSIF p_period = 'monthly' THEN
        v_start_date := date_trunc('month', now() AT TIME ZONE v_tz) AT TIME ZONE v_tz;
        v_end_date := v_start_date + interval '1 month';
    ELSIF p_period = 'yearly' THEN
        v_start_date := date_trunc('year', now() AT TIME ZONE v_tz) AT TIME ZONE v_tz;
        v_end_date := v_start_date + interval '1 year';
    ELSE
        -- Fallback to today
        v_start_date := date_trunc('day', now() AT TIME ZONE v_tz) AT TIME ZONE v_tz;
        v_end_date := v_start_date + interval '1 day';
    END IF;

    -- Aggregate Scalars (Total Sales, Count)
    SELECT COALESCE(SUM(total_amount), 0), COUNT(id)
    INTO v_sales, v_txn_count
    FROM public.transactions
    WHERE transaction_date >= v_start_date 
      AND transaction_date < v_end_date
      AND (status = 'PAID' OR status IS NULL)
      AND transaction_type = 'SALE'
      AND (p_outlet_id IS NULL OR outlet_id = p_outlet_id);

    -- Aggregate COGS dynamically by joining transaction_items -> products
    SELECT COALESCE(SUM(ti.quantity * p.purchase_price), 0)
    INTO v_cogs
    FROM public.transaction_items ti
    JOIN public.transactions t ON t.id = ti.transaction_id
    JOIN public.products p ON p.id = ti.product_id
    WHERE t.transaction_date >= v_start_date 
      AND t.transaction_date < v_end_date
      AND (t.status = 'PAID' OR t.status IS NULL)
      AND t.transaction_type = 'SALE'
      AND (p_outlet_id IS NULL OR t.outlet_id = p_outlet_id);

    -- Build Trend Array
    IF p_period = 'daily' THEN
        -- Group by Hour (00 - 23) in local timezone
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'label', lpad(h.hour::TEXT, 2, '0') || ':00',
                'amount', COALESCE(agg.amount, 0)
            )
        ), '[]'::JSONB) INTO v_trend
        FROM generate_series(0, 23) AS h(hour)
        LEFT JOIN (
            SELECT EXTRACT(HOUR FROM transaction_date AT TIME ZONE v_tz) as hr, SUM(total_amount) as amount
            FROM public.transactions
            WHERE transaction_date >= v_start_date AND transaction_date < v_end_date
              AND (status = 'PAID' OR status IS NULL) AND transaction_type = 'SALE'
              AND (p_outlet_id IS NULL OR outlet_id = p_outlet_id)
            GROUP BY EXTRACT(HOUR FROM transaction_date AT TIME ZONE v_tz)
        ) agg ON agg.hr = h.hour;

    ELSIF p_period = 'monthly' THEN
        -- Group by Day (1 - days_in_month) in local timezone
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'label', d.day::TEXT,
                'amount', COALESCE(agg.amount, 0)
            )
        ), '[]'::JSONB) INTO v_trend
        FROM generate_series(1, EXTRACT(DAY FROM (v_end_date AT TIME ZONE v_tz - interval '1 day'))::INT) AS d(day)
        LEFT JOIN (
            SELECT EXTRACT(DAY FROM transaction_date AT TIME ZONE v_tz) as dy, SUM(total_amount) as amount
            FROM public.transactions
            WHERE transaction_date >= v_start_date AND transaction_date < v_end_date
              AND (status = 'PAID' OR status IS NULL) AND transaction_type = 'SALE'
              AND (p_outlet_id IS NULL OR outlet_id = p_outlet_id)
            GROUP BY EXTRACT(DAY FROM transaction_date AT TIME ZONE v_tz)
        ) agg ON agg.dy = d.day;

    ELSIF p_period = 'yearly' THEN
        -- Group by Month (1 - 12) in local timezone
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'label', to_char(to_date(m.month::TEXT, 'MM'), 'Mon'),
                'amount', COALESCE(agg.amount, 0)
            )
        ), '[]'::JSONB) INTO v_trend
        FROM generate_series(1, 12) AS m(month)
        LEFT JOIN (
            SELECT EXTRACT(MONTH FROM transaction_date AT TIME ZONE v_tz) as mn, SUM(total_amount) as amount
            FROM public.transactions
            WHERE transaction_date >= v_start_date AND transaction_date < v_end_date
              AND (status = 'PAID' OR status IS NULL) AND transaction_type = 'SALE'
              AND (p_outlet_id IS NULL OR outlet_id = p_outlet_id)
            GROUP BY EXTRACT(MONTH FROM transaction_date AT TIME ZONE v_tz)
        ) agg ON agg.mn = m.month;
    END IF;

    -- Return Consolidated JSON
    RETURN jsonb_build_object(
        'total_sales', v_sales,
        'total_cogs', v_cogs,
        'gross_profit', v_sales - v_cogs,
        'transaction_count', v_txn_count,
        'sales_trend', v_trend
    );
END;
$$;

-- Give access to the anonymous/authenticated roles
GRANT EXECUTE ON FUNCTION public.get_dashboard_metrics(TEXT, UUID) TO anon, authenticated;
GRANT SELECT ON public.outlets TO anon, authenticated;

-- Reload cache
NOTIFY pgrst, 'reload schema';
