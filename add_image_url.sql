-- Add image_url column to products table
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url TEXT;
COMMENT ON COLUMN public.products.image_url IS 'URL to the product image.';

-- Seed default categories (Beverage, Food, Snack, Other)
INSERT INTO public.categories (name, description) VALUES
  ('Beverage', 'Drinks and beverages'),
  ('Food', 'Main food items'),
  ('Snack', 'Snacks and light bites'),
  ('Other', 'Other items')
ON CONFLICT (name) DO NOTHING;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
