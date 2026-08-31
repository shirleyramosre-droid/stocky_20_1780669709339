-- Stocky App: Initial Schema Migration
-- Tables: categories, products, sales

-- ─── 1. CATEGORIES TABLE ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    is_hidden BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ─── 2. PRODUCTS TABLE ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    size TEXT,
    purchase_price NUMERIC(10,2) NOT NULL DEFAULT 0,
    stock INTEGER NOT NULL DEFAULT 0,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ─── 3. SALES TABLE ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    product_category TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    sale_price NUMERIC(10,2) NOT NULL DEFAULT 0,
    cost_price NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_sale NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_cost NUMERIC(10,2) NOT NULL DEFAULT 0,
    payment_method TEXT NOT NULL DEFAULT 'EFECTIVO',
    sold_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ─── 4. INDEXES ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_stock ON public.products(stock);
CREATE INDEX IF NOT EXISTS idx_sales_sold_at ON public.sales(sold_at);
CREATE INDEX IF NOT EXISTS idx_sales_product_id ON public.sales(product_id);
CREATE INDEX IF NOT EXISTS idx_categories_name ON public.categories(name);

-- ─── 5. UPDATED_AT TRIGGER FUNCTION ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_categories_updated_at ON public.categories;
CREATE TRIGGER set_categories_updated_at
    BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_products_updated_at ON public.products;
CREATE TRIGGER set_products_updated_at
    BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─── 6. ENABLE RLS ───────────────────────────────────────────────────────────
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;

-- ─── 7. RLS POLICIES (open access - no auth required) ───────────────────────
DROP POLICY IF EXISTS "open_access_categories" ON public.categories;
CREATE POLICY "open_access_categories" ON public.categories
    FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "open_access_products" ON public.products;
CREATE POLICY "open_access_products" ON public.products
    FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "open_access_sales" ON public.sales;
CREATE POLICY "open_access_sales" ON public.sales
    FOR ALL TO public USING (true) WITH CHECK (true);

-- ─── 8. SEED DEFAULT CATEGORIES ─────────────────────────────────────────────
DO $$
BEGIN
    INSERT INTO public.categories (name) VALUES
        ('Polos'),
        ('Pantalones'),
        ('Vestidos'),
        ('Casacas'),
        ('Shorts'),
        ('Blusas'),
        ('Faldas')
    ON CONFLICT (name) DO NOTHING;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Seed categories failed: %', SQLERRM;
END $$;
