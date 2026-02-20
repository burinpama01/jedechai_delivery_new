# Supabase Migrations Consolidation

## Result
ได้ยุบรวม migration กลุ่มที่แตกย่อย/ซ้ำกันไว้ในไฟล์เดียว:

- `supabase/migrations/20260301_consolidated_rls_and_feature_columns.sql`

ไฟล์นี้ครอบคลุมหัวข้อหลักที่เคยกระจายหลายไฟล์:
- feature columns (profiles/system_config/bookings/menu_items)
- banners schema + indexes + trigger + RLS
- topup_requests / account_deletion_requests / reviews
- RLS fixes (service_rates/system_config/profiles/driver_locations/driver_activity_logs)

---

## Audit Summary (current)
ใน `supabase/migrations` มีไฟล์ทั้งหมด 38 ไฟล์ (รวมไฟล์ consolidated ใหม่)

### A) กลุ่ม debug/check/manual (ไม่ควรเป็น production migration)
ไฟล์กลุ่มนี้ควรย้ายไปโฟลเดอร์ `supabase/manual_sql/` ในรอบถัดไป:

- `20240211_check_admin_user.sql`
- `20240211_check_existing_admin.sql`
- `20240211_check_bucket.sql`
- `20240211_check_schema.sql`
- `20240211_check_system_config.sql`
- `20240211_debug_rls.sql`
- `20240211_create_admin_user.sql`
- `20240211_approve_admin.sql`

### B) กลุ่มที่ถูก supersede โดย consolidated migration
ไฟล์เหล่านี้ยังคงอยู่เพื่อ backward compatibility แต่ logic หลักถูกรวมแล้ว:

- `20240211_create_banners_table.sql`
- `20240211_fix_all_rls.sql`
- `20240211_fix_rls_final.sql`
- `20240211_simple_rls_fix.sql`
- `20240211_clean_rls.sql`
- `20240212_add_page_to_banners.sql`
- `20240213_add_coupon_code_to_banners.sql`
- `20240213_fix_system_config_columns.sql`
- `20240215_topup_requests_and_promptpay.sql`
- `20240216_fix_service_rates_rls.sql`
- `20240225_ensure_banners_table_complete.sql`
- `20240226_fix_profiles_driver_locations_rls.sql`
- `20240227_fix_driver_activity_logs_rls.sql`
- `20240228_ensure_merchant_shop_status.sql`
- `20240229_reviews_table_and_rls.sql`

---

## Recommended Execution
1. สำหรับฐานข้อมูลใหม่: รัน consolidated migration ก่อน
2. รันเฉพาะ migration feature ที่ออกใหม่กว่าจุด consolidated
3. สำหรับฐานข้อมูลเดิม: สามารถรัน consolidated เพิ่มได้ (idempotent)

---

## Next Safe Cleanup (optional)
ถ้าต้องการลดจำนวนไฟล์จริงในโฟลเดอร์ `migrations`:
1. สร้างโฟลเดอร์ `supabase/manual_sql/`
2. ย้ายไฟล์ในกลุ่ม A ออกไป
3. ยืนยันว่า CI/deploy ใช้ migration ตาม canonical list เท่านั้น
