-- Migration: Add device_id column to products and sales tables
-- This enables per-device data isolation without authentication

-- ─── 1. ADD device_id TO products ────────────────────────────────────────────
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS device_id TEXT DEFAULT NULL;

-- ─── 2. ADD device_id TO sales ───────────────────────────────────────────────
ALTER TABLE public.sales
ADD COLUMN IF NOT EXISTS device_id TEXT DEFAULT NULL;

-- ─── 3. INDEXES for fast device_id filtering ─────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_products_device_id ON public.products(device_id);
CREATE INDEX IF NOT EXISTS idx_sales_device_id ON public.sales(device_id);
