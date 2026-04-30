-- Repair active food bookings that were created with the old Bangkok fallback
-- instead of the merchant's real profile location.

UPDATE public.bookings AS b
SET
  origin_lat = p.latitude,
  origin_lng = p.longitude,
  pickup_address = COALESCE(NULLIF(BTRIM(p.shop_address), ''), p.full_name, b.pickup_address),
  updated_at = NOW()
FROM public.profiles AS p
WHERE b.service_type = 'food'
  AND b.merchant_id = p.id
  AND p.latitude IS NOT NULL
  AND p.longitude IS NOT NULL
  AND p.latitude BETWEEN -90 AND 90
  AND p.longitude BETWEEN -180 AND 180
  AND NOT (p.latitude = 0 AND p.longitude = 0)
  AND b.status NOT IN ('completed', 'cancelled')
  AND (
    b.origin_lat IS NULL
    OR b.origin_lng IS NULL
    OR (b.origin_lat = 0 AND b.origin_lng = 0)
    OR (
      ABS(b.origin_lat - 13.7563) <= 0.001
      AND ABS(b.origin_lng - 100.5018) <= 0.001
    )
  );
