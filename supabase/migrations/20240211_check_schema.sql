-- Check table schemas
-- Run this in Supabase SQL Editor

-- 1. Check profiles table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 2. Check auth.users structure (limited view)
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'users'
ORDER BY ordinal_position;

-- 3. Check storage.objects structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'storage' AND table_name = 'objects'
ORDER BY ordinal_position;

-- 4. Sample data from profiles
SELECT * FROM public.profiles LIMIT 5;
