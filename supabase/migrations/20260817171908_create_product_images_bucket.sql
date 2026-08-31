-- Create public bucket for product images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'product-images',
    'product-images',
    true,
    10485760,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO NOTHING;

-- RLS: Anyone can view product images (public catalog)
DROP POLICY IF EXISTS "public_read_product_images" ON storage.objects;
CREATE POLICY "public_read_product_images" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'product-images');

-- RLS: Anyone can upload product images (no auth required for this app)
DROP POLICY IF EXISTS "anyone_upload_product_images" ON storage.objects;
CREATE POLICY "anyone_upload_product_images" ON storage.objects
FOR INSERT TO public
WITH CHECK (bucket_id = 'product-images');

-- RLS: Anyone can update product images
DROP POLICY IF EXISTS "anyone_update_product_images" ON storage.objects;
CREATE POLICY "anyone_update_product_images" ON storage.objects
FOR UPDATE TO public
USING (bucket_id = 'product-images');

-- RLS: Anyone can delete product images
DROP POLICY IF EXISTS "anyone_delete_product_images" ON storage.objects;
CREATE POLICY "anyone_delete_product_images" ON storage.objects
FOR DELETE TO public
USING (bucket_id = 'product-images');
