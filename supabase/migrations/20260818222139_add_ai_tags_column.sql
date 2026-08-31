-- Add ai_tags column to products table
ALTER TABLE products ADD COLUMN IF NOT EXISTS ai_tags TEXT;
