-- Add per-merchant custom fee columns to profiles table
-- These allow admin to set delivery fee and service fee per merchant
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_delivery_fee numeric;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_service_fee numeric;
