-- ============================================================
-- FIX OUTLETS RLS — match existing anon pattern
-- ============================================================

-- Drop the incorrect policy
DROP POLICY IF EXISTS "Authenticated users can manage outlets" ON public.outlets;

-- Create proper policies matching the rest of the app
CREATE POLICY "Outlets: full access for authenticated"
    ON public.outlets FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

CREATE POLICY "Outlets: full access for anon"
    ON public.outlets FOR ALL
    TO anon
    USING (TRUE)
    WITH CHECK (TRUE);

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
