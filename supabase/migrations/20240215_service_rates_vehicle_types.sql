-- Add vehicle-type-specific ride rates to service_rates
-- and per-merchant base_fare / per_km columns to profiles

-- Ensure ride_motorcycle rate exists
INSERT INTO public.service_rates (service_type, base_price, base_distance, price_per_km)
VALUES ('ride_motorcycle', 25, 2, 8)
ON CONFLICT (service_type) DO NOTHING;

-- Ensure ride_car rate exists
INSERT INTO public.service_rates (service_type, base_price, base_distance, price_per_km)
VALUES ('ride_car', 40, 2, 12)
ON CONFLICT (service_type) DO NOTHING;

-- Ensure parcel rate exists
INSERT INTO public.service_rates (service_type, base_price, base_distance, price_per_km)
VALUES ('parcel', 30, 3, 10)
ON CONFLICT (service_type) DO NOTHING;

-- Ensure food rate exists
INSERT INTO public.service_rates (service_type, base_price, base_distance, price_per_km)
VALUES ('food', 15, 2, 10)
ON CONFLICT (service_type) DO NOTHING;

-- Per-merchant rate override columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_base_fare numeric;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_per_km numeric;
