-- Remove duplicate system_config rows — keep only id=1 (the canonical config row)
-- Caused by a bug in handleUpsertSystemConfig fallback path that inserted without id
DELETE FROM public.system_config WHERE id != 1;
