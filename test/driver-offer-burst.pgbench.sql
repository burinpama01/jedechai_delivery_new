INSERT INTO public.bookings(id, customer_id, service_type, status, origin_lat, origin_lng)
VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000099',
  'parcel', 'pending', 13.0001, 100.0000);
