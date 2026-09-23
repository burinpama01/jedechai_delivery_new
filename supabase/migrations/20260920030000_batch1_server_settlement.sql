-- ═══════════════════════════════════════════════════════════════
-- Batch 1 — เงินปลอดภัย: server คำนวณ settlement เอง (Master_Plan_Summary_v1)
--
--  G2  complete_booking ไม่เชื่อ commission/earnings จาก client — คำนวณจาก DB
--  G1  snapshot อัตรา GP/ค่าส่ง ตอนสร้างออเดอร์ (ใช้ rate ณ วันสั่ง)
--  G4  เติม total_amount / platform_gp_amount / merchant_net_amount ตอนจบงาน
--  W1  ออเดอร์จ่ายผ่าน Wallet (non-laundry) → เครดิตคนขับเท่ายอดที่ลูกค้าจ่าย (job_payout)
--  A   ชดเชยส่วนลดคูปอง (ที่ platform/split เป็นผู้ออกเงิน) เข้ากระเป๋าคนขับ + แจ้งเตือน
--      (แทน referral offset เดิมที่หักค่าคอมลด/ตัดรายได้คนขับ)
--  F2  ยกเลิกจาก JDC ตั้ง status_origin='jdc' เสมอ (POS ได้ webhook)
--  C2  ยกเลิกแล้วคืนคูปอง
--  C3  apply_coupon_atomic คำนวณส่วนลดเองจาก booking + ตรวจเจ้าของ
--  Guard: client (ไม่ใช่แอดมิน) ห้ามตั้ง status='completed' ตรง / ห้ามแก้คอลัมน์เงิน
--
-- สูตรเลียนแบบแอป (MerchantFoodConfigService.resolve + DriverAmountCalculator.foodOrderSettlement
-- + _getFoodCouponFinanceContext + SystemConfigService.calculateCommission)
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- 0) helpers -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._parse_rate(p_raw text, p_fallback numeric)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v numeric;
BEGIN
  IF p_raw IS NULL OR btrim(p_raw) = '' THEN
    RETURN p_fallback;
  END IF;
  BEGIN
    v := btrim(p_raw)::numeric;
  EXCEPTION WHEN others THEN
    RETURN p_fallback;
  END;
  IF v < 0 THEN RETURN p_fallback; END IF;
  IF v > 1 THEN RETURN 1; END IF;
  RETURN v;
END;
$$;

CREATE OR REPLACE FUNCTION public._clamp01(p numeric)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$ SELECT LEAST(GREATEST(COALESCE(p, 0), 0), 1) $$;

CREATE OR REPLACE FUNCTION public._ceil_money(p numeric)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$ SELECT CASE WHEN COALESCE(p, 0) <= 0 THEN 0 ELSE ceil(p) END $$;

-- อัตราของร้านอาหาร: ระบบ / คนขับ / ค่าส่ง (ลำดับความสำคัญเดียวกับแอป)
CREATE OR REPLACE FUNCTION public.food_gp_rates(p_merchant_id uuid)
RETURNS TABLE(system_rate numeric, driver_rate numeric, delivery_rate numeric)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gp numeric; v_psys numeric; v_pdrv numeric;
  v_sc record;
  v_def_sys numeric; v_def_drv numeric; v_def_delivery numeric;
  v_kv_sys text; v_kv_drv text; v_kv_msys text; v_kv_mdrv text;
  v_pre_sys numeric; v_pre_drv numeric; v_pre_del numeric;
  v_sys numeric; v_drv numeric; v_max numeric; v_over numeric;
BEGIN
  SELECT gp_rate, merchant_gp_system_rate, merchant_gp_driver_rate
    INTO v_gp, v_psys, v_pdrv
  FROM public.profiles WHERE id = p_merchant_id;

  SELECT merchant_gp_rate, merchant_gp_system_rate_default, merchant_gp_driver_rate_default, platform_fee_rate
    INTO v_sc
  FROM public.system_config WHERE id = 1;

  v_def_sys := COALESCE(v_sc.merchant_gp_rate, 0.10);
  v_def_drv := 0;
  IF v_sc.merchant_gp_system_rate_default IS NOT NULL THEN
    v_def_sys := public._parse_rate(v_sc.merchant_gp_system_rate_default::text, v_def_sys);
  END IF;
  IF v_sc.merchant_gp_driver_rate_default IS NOT NULL THEN
    v_def_drv := public._parse_rate(v_sc.merchant_gp_driver_rate_default::text, v_def_drv);
  END IF;

  SELECT max(value) FILTER (WHERE key = 'merchant_gp_system_rate_default'),
         max(value) FILTER (WHERE key = 'merchant_gp_driver_rate_default'),
         max(value) FILTER (WHERE key = 'merchant_gp_system_rate_' || p_merchant_id::text),
         max(value) FILTER (WHERE key = 'merchant_gp_driver_rate_' || p_merchant_id::text)
    INTO v_kv_sys, v_kv_drv, v_kv_msys, v_kv_mdrv
  FROM public.system_config
  WHERE key IS NOT NULL;

  v_def_sys := public._parse_rate(v_kv_msys, public._parse_rate(v_kv_sys, v_def_sys));
  v_def_drv := public._parse_rate(v_kv_mdrv, public._parse_rate(v_kv_drv, v_def_drv));
  v_def_delivery := COALESCE(v_sc.platform_fee_rate, 0.15);

  IF v_gp IS NOT NULL THEN
    IF abs(v_gp - 0.10) < 0.0001 THEN
      v_pre_sys := 0.10; v_pre_drv := 0.00; v_pre_del := 0.02;
    ELSIF abs(v_gp - 0.20) < 0.0001 THEN
      v_pre_sys := 0.10; v_pre_drv := 0.10; v_pre_del := 0.01;
    ELSIF abs(v_gp - 0.25) < 0.0001 THEN
      v_pre_sys := 0.13; v_pre_drv := 0.12; v_pre_del := 0.00;
    END IF;
  END IF;

  v_sys := public._clamp01(COALESCE(v_psys, v_pre_sys, v_gp, v_def_sys));
  v_drv := public._clamp01(COALESCE(v_pdrv, v_pre_drv, v_def_drv));

  IF v_gp IS NOT NULL THEN
    v_max := public._clamp01(v_gp);
    IF v_sys + v_drv > v_max THEN
      v_over := (v_sys + v_drv) - v_max;
      IF v_drv >= v_over THEN
        v_drv := v_drv - v_over;
      ELSE
        v_drv := 0;
        v_sys := v_max;
      END IF;
    END IF;
  END IF;

  system_rate := v_sys;
  driver_rate := v_drv;
  delivery_rate := public._clamp01(COALESCE(v_pre_del, v_def_delivery));
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.food_gp_rates(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.food_gp_rates(uuid) TO authenticated, service_role;

-- ให้ webhook StoreOS ใช้อัตราเดียวกับแอป (เดิมใช้ default คนละตัว)
CREATE OR REPLACE FUNCTION public.connect_merchant_gp_amount(p_merchant_id uuid, p_food_price numeric)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rates record;
  v_price numeric := GREATEST(COALESCE(p_food_price, 0), 0);
BEGIN
  SELECT * INTO v_rates FROM public.food_gp_rates(p_merchant_id);
  RETURN public._ceil_money(v_price * v_rates.system_rate)
       + public._ceil_money(v_price * v_rates.driver_rate);
END;
$$;

-- 1) G1 snapshot rate ตอนสร้างออเดอร์อาหาร ----------------------------------
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS gp_system_rate_at_order numeric,
  ADD COLUMN IF NOT EXISTS gp_driver_rate_at_order numeric,
  ADD COLUMN IF NOT EXISTS delivery_system_rate_at_order numeric;

COMMENT ON COLUMN public.bookings.gp_system_rate_at_order IS 'อัตรา GP เข้าระบบ ณ เวลาสร้างออเดอร์ (ใช้คำนวณตอนจบงาน)';

CREATE OR REPLACE FUNCTION public.snapshot_booking_gp_rates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rates record;
BEGIN
  IF NEW.service_type = 'food' AND NEW.merchant_id IS NOT NULL THEN
    SELECT * INTO v_rates FROM public.food_gp_rates(NEW.merchant_id);
    NEW.gp_system_rate_at_order := v_rates.system_rate;
    NEW.gp_driver_rate_at_order := v_rates.driver_rate;
    NEW.delivery_system_rate_at_order := v_rates.delivery_rate;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_snapshot_booking_gp_rates ON public.bookings;
CREATE TRIGGER trg_snapshot_booking_gp_rates
  BEFORE INSERT ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.snapshot_booking_gp_rates();

-- 2) Settlement (คำนวณอย่างเดียว ไม่ขยับเงิน) --------------------------------
CREATE OR REPLACE FUNCTION public.booking_settlement(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  b record;
  v_rates record;
  v_sc record;
  v_usage record;
  v_coupon public.coupons%ROWTYPE;
  v_sys numeric; v_drv numeric; v_del numeric; v_driver_override numeric;
  v_food numeric; v_fee numeric; v_price numeric;
  v_dsf numeric := 0; v_msgp numeric := 0; v_mdgp numeric := 0;
  v_commission numeric := 0; v_app numeric := 0; v_driver_net numeric := 0;
  v_platform_gp numeric := 0; v_merchant_net numeric := 0;
  v_discount numeric := 0; v_compensation numeric := 0; v_payout numeric := 0;
  v_merchant_fd boolean := false;
  v_extra_sys numeric := 0; v_extra_drv numeric := 0; v_def_gp numeric;
  v_rate numeric;
BEGIN
  SELECT * INTO b FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'booking_not_found');
  END IF;

  SELECT commission_rate, merchant_gp_rate INTO v_sc FROM public.system_config WHERE id = 1;

  SELECT cu.discount_amount, cu.coupon_id INTO v_usage
  FROM public.coupon_usages cu WHERE cu.booking_id = p_booking_id
  ORDER BY cu.created_at LIMIT 1;
  IF FOUND THEN
    v_discount := GREATEST(COALESCE(v_usage.discount_amount, 0), 0);
    SELECT * INTO v_coupon FROM public.coupons WHERE id = v_usage.coupon_id;
  END IF;

  IF b.service_type = 'food' THEN
    v_food := GREATEST(COALESCE(b.price, 0), 0);
    v_fee := GREATEST(COALESCE(b.delivery_fee, 0), 0);

    IF b.gp_system_rate_at_order IS NOT NULL THEN
      v_sys := b.gp_system_rate_at_order;
      v_drv := COALESCE(b.gp_driver_rate_at_order, 0);
      v_del := COALESCE(b.delivery_system_rate_at_order, 0);
    ELSE
      SELECT * INTO v_rates FROM public.food_gp_rates(b.merchant_id);
      v_sys := v_rates.system_rate; v_drv := v_rates.driver_rate; v_del := v_rates.delivery_rate;
    END IF;

    SELECT driver_delivery_system_rate INTO v_driver_override
    FROM public.profiles WHERE id = b.driver_id;
    IF v_driver_override IS NOT NULL AND v_driver_override BETWEEN 0 AND 1 THEN
      v_del := v_driver_override;
    END IF;

    v_dsf := public._ceil_money(v_fee * public._clamp01(v_del));
    v_msgp := public._ceil_money(v_food * public._clamp01(v_sys));
    v_mdgp := public._ceil_money(v_food * public._clamp01(v_drv));
    v_commission := v_dsf + v_msgp;
    v_app := v_commission;
    v_driver_net := GREATEST((v_fee - v_dsf) + v_mdgp, 0);
    v_platform_gp := v_msgp + v_mdgp;
    v_merchant_net := GREATEST(v_food - v_platform_gp, 0);

    -- คูปองส่งฟรีของร้าน (ส่งฟรีเต็มจำนวน) → ร้านจ่าย GP เพิ่ม (ระบบ + อุดหนุนคนขับ)
    IF v_coupon.id IS NOT NULL
       AND v_coupon.merchant_id IS NOT NULL AND v_coupon.merchant_id = b.merchant_id
       AND v_coupon.discount_type = 'free_delivery'
       AND (v_fee <= 0 OR v_discount >= v_fee) THEN
      v_merchant_fd := true;
      v_def_gp := COALESCE(v_sc.merchant_gp_rate, 0.10);
      v_extra_sys := ceil(v_food * COALESCE(v_coupon.merchant_gp_system_rate, v_def_gp));
      v_extra_drv := ceil(v_food * COALESCE(v_coupon.merchant_gp_driver_rate, GREATEST(0.25 - v_def_gp, 0)));
      v_commission := v_commission + v_extra_sys;
      v_app := v_app + v_extra_sys;
      v_driver_net := v_driver_net + v_extra_drv;
      v_platform_gp := v_platform_gp + v_extra_sys + v_extra_drv;
      v_merchant_net := GREATEST(v_food - v_platform_gp, 0);
    END IF;

    v_price := v_food + v_fee;
  ELSE
    -- ride / parcel: ปัดเศษราคาทิ้ง (toInt) แล้ว ceil(price × commission%)
    v_price := GREATEST(COALESCE(b.price, 0), 0);
    v_rate := COALESCE(v_sc.commission_rate, 15) / 100.0;
    v_commission := ceil(trunc(v_price) * v_rate);
    v_app := v_commission;
    v_driver_net := v_price - v_commission;
  END IF;

  -- A: ชดเชยส่วนลดที่ platform/split ออกเงิน (คูปองของร้านเอง ร้านเป็นคนแบก)
  IF v_discount > 0 AND NOT v_merchant_fd
     AND COALESCE(v_coupon.funding_source, 'platform') <> 'merchant' THEN
    v_compensation := round(v_discount, 2);
    v_app := v_app - v_compensation;
  END IF;

  -- W1: ลูกค้าจ่ายผ่าน Wallet → คนขับไม่ได้เก็บเงินสด → เครดิตเท่ายอดที่ลูกค้าจ่ายจริง
  IF lower(COALESCE(b.payment_method, '')) = 'wallet' AND b.service_type <> 'laundry' THEN
    SELECT COALESCE(SUM(ABS(wt.amount)), 0) INTO v_payout
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON w.id = wt.wallet_id
    WHERE wt.related_booking_id = p_booking_id::text
      AND wt.type = 'payment' AND wt.amount < 0
      AND w.user_id = b.customer_id;
  END IF;

  RETURN jsonb_build_object(
    'service_type', b.service_type,
    'commission', v_commission,
    'driver_earnings', v_driver_net,
    'app_earnings', v_app,
    'delivery_system_fee', v_dsf,
    'merchant_system_gp', v_msgp,
    'merchant_driver_gp', v_mdgp,
    'platform_gp_amount', v_platform_gp,
    'merchant_net_amount', v_merchant_net,
    'coupon_discount', v_discount,
    'coupon_compensation', v_compensation,
    'wallet_payout', v_payout,
    'total_amount', GREATEST(v_price - v_discount, 0),
    'rates', jsonb_build_object('system', v_sys, 'driver', v_drv, 'delivery', v_del)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.booking_settlement(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.booking_settlement(uuid) TO service_role;

-- 3) complete_booking (server authoritative) -------------------------------
CREATE OR REPLACE FUNCTION public.complete_booking(
  p_booking_id uuid,
  p_driver_id uuid,
  p_commission_amount numeric DEFAULT 0,
  p_driver_earnings numeric DEFAULT 0,
  p_app_earnings numeric DEFAULT 0,
  p_description text DEFAULT ''::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_status text;
  v_driver_id uuid;
  v_service text;
  v_s jsonb;
  v_commission numeric; v_comp numeric; v_payout numeric;
  v_wallet_result jsonb;
  v_code text;
BEGIN
  SELECT status, driver_id, service_type INTO v_status, v_driver_id, v_service
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    IF auth.uid() <> p_driver_id OR v_driver_id IS DISTINCT FROM p_driver_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'forbidden');
    END IF;
  END IF;

  IF v_service = 'laundry' THEN
    RETURN jsonb_build_object('success', false, 'error', 'use_complete_laundry_booking');
  END IF;

  IF v_status NOT IN ('in_transit', 'arrived', 'picking_up_order', 'driver_accepted', 'ready_for_pickup', 'arrived_at_merchant') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'current_status', v_status);
  END IF;

  v_s := public.booking_settlement(p_booking_id);
  v_commission := COALESCE((v_s->>'commission')::numeric, 0);
  v_comp := COALESCE((v_s->>'coupon_compensation')::numeric, 0);
  v_payout := COALESCE((v_s->>'wallet_payout')::numeric, 0);
  v_code := 'FD-' || upper(left(p_booking_id::text, 8));

  -- W1: เครดิตค่าออเดอร์ที่ลูกค้าจ่ายผ่าน Wallet
  IF v_payout > 0 AND NOT EXISTS (
    SELECT 1 FROM public.wallet_transactions wt JOIN public.wallets w ON w.id = wt.wallet_id
    WHERE w.user_id = p_driver_id AND wt.related_booking_id = p_booking_id::text AND wt.type = 'job_payout'
  ) THEN
    v_wallet_result := public.wallet_topup(
      p_driver_id, v_payout,
      'รับค่าออเดอร์ ' || v_code || ' (ลูกค้าจ่ายผ่าน Wallet)',
      'job_payout', p_booking_id);
    IF COALESCE((v_wallet_result->>'success')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'job_payout_failed: %', COALESCE(v_wallet_result->>'error', 'unknown');
    END IF;
  END IF;

  IF v_commission > 0 THEN
    v_wallet_result := public.wallet_deduct(
      p_driver_id, v_commission,
      'หักค่าบริการระบบ ออเดอร์ ' || v_code,
      'commission', p_booking_id);
    IF NOT COALESCE((v_wallet_result->>'success')::boolean, false) THEN
      -- RAISE เพื่อ rollback job_payout ที่อาจเครดิตไปแล้วในธุรกรรมเดียวกัน
      RAISE EXCEPTION 'settlement_failed: %', COALESCE(v_wallet_result->>'error', 'unknown');
    END IF;
  END IF;

  -- A: ชดเชยส่วนลดคูปอง + แจ้งเตือนคนขับ
  IF v_comp > 0 AND NOT EXISTS (
    SELECT 1 FROM public.wallet_transactions wt JOIN public.wallets w ON w.id = wt.wallet_id
    WHERE w.user_id = p_driver_id AND wt.related_booking_id = p_booking_id::text AND wt.type = 'coupon_compensation'
  ) THEN
    v_wallet_result := public.wallet_topup(
      p_driver_id, v_comp,
      'ชดเชยส่วนลดคูปอง ออเดอร์ ' || v_code,
      'coupon_compensation', p_booking_id);
    IF COALESCE((v_wallet_result->>'success')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'coupon_compensation_failed: %', COALESCE(v_wallet_result->>'error', 'unknown');
    END IF;
    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (
      p_driver_id,
      '💵 ชดเชยส่วนลดคูปอง',
      'ระบบเติมเงินชดเชยส่วนลด ฿' || trim(to_char(v_comp, 'FM999G999D00')) || ' สำหรับออเดอร์ ' || v_code || ' เข้ากระเป๋าของคุณแล้ว',
      'driver.coupon_compensated',
      jsonb_build_object('type', 'driver.coupon_compensated', 'booking_id', p_booking_id,
                         'amount', v_comp, 'screen', 'wallet'));
  END IF;

  UPDATE public.bookings
  SET status = 'completed',
      status_origin = 'jdc',
      completed_at = now(),
      driver_earnings = (v_s->>'driver_earnings')::numeric,
      app_earnings = (v_s->>'app_earnings')::numeric,
      total_amount = (v_s->>'total_amount')::numeric,
      platform_gp_amount = CASE WHEN v_service = 'food' THEN (v_s->>'platform_gp_amount')::numeric ELSE platform_gp_amount END,
      merchant_net_amount = CASE WHEN v_service = 'food' THEN (v_s->>'merchant_net_amount')::numeric ELSE merchant_net_amount END,
      details = COALESCE(details, '{}'::jsonb) || jsonb_build_object(
        'settlement', v_s,
        'client_claimed', jsonb_build_object(
          'commission', p_commission_amount, 'driver_earnings', p_driver_earnings,
          'app_earnings', p_app_earnings)),
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'settlement', v_s,
    'wallet', COALESCE(v_wallet_result, '{}'::jsonb)
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.complete_booking(uuid, uuid, numeric, numeric, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_booking(uuid, uuid, numeric, numeric, numeric, text) TO authenticated, service_role;

-- 4) คืนคูปองเมื่อยกเลิก (C2) ---------------------------------------------
CREATE OR REPLACE FUNCTION public._release_booking_coupon(p_booking_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
  v_n integer := 0;
BEGIN
  FOR v_row IN
    DELETE FROM public.coupon_usages WHERE booking_id = p_booking_id RETURNING coupon_id
  LOOP
    UPDATE public.coupons SET used_count = GREATEST(COALESCE(used_count, 0) - 1, 0)
    WHERE id = v_row.coupon_id;
    v_n := v_n + 1;
  END LOOP;

  UPDATE public.user_coupons
  SET status = 'claimed', used_booking_id = NULL, used_at = NULL, updated_at = now()
  WHERE used_booking_id = p_booking_id AND status = 'used';

  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION public._release_booking_coupon(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.cancel_wallet_booking_with_refund(p_booking_id uuid, p_reason text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_booking record;
  v_refund_amount numeric := 0;
  v_refund_result jsonb := NULL;
  v_coupons_released integer := 0;
BEGIN
  IF v_auth_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT id, customer_id, status, service_type, payment_method
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.customer_id <> v_auth_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF NOT (v_booking.status = ANY (ARRAY['pending', 'pending_merchant', 'preparing'])) THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_cancellable');
  END IF;

  IF lower(COALESCE(v_booking.payment_method, '')) = 'wallet' THEN
    SELECT COALESCE(SUM(ABS(wt.amount)), 0)
    INTO v_refund_amount
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON w.id = wt.wallet_id
    WHERE wt.related_booking_id = p_booking_id::text
      AND wt.type = 'payment'
      AND wt.amount < 0
      AND w.user_id = v_booking.customer_id;

    IF COALESCE(v_refund_amount, 0) <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'wallet_payment_not_found', 'booking_id', p_booking_id);
    END IF;

    v_refund_result := public.refund_booking_to_customer_wallet(
      p_booking_id, v_refund_amount, 'คืนเงินจากการยกเลิกออเดอร์');

    IF COALESCE((v_refund_result->>'success')::boolean, false) IS NOT TRUE
      AND COALESCE(v_refund_result->>'error', '') <> 'already_refunded' THEN
      RETURN jsonb_build_object('success', false, 'error', 'wallet_refund_failed',
                                'booking_id', p_booking_id, 'refund', v_refund_result);
    END IF;
  END IF;

  v_coupons_released := public._release_booking_coupon(p_booking_id);

  UPDATE public.bookings
  SET status = 'cancelled',
      status_origin = 'jdc',
      cancellation_reason = COALESCE(p_reason, ''),
      notes = COALESCE(p_reason, notes),
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'refunded', v_refund_result IS NOT NULL,
    'refund_amount', v_refund_amount,
    'refund', v_refund_result,
    'coupons_released', v_coupons_released
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_force_cancel_booking_with_wallet_refund(p_booking_id uuid, p_reason text DEFAULT NULL::text, p_do_refund boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_booking record;
  v_payment_amount numeric := 0;
  v_hold_amount numeric := 0;
  v_refund_amount numeric := 0;
  v_refund_result jsonb;
  v_should_refund boolean := false;
  v_coupons_released integer := 0;
BEGIN
  IF p_booking_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_booking_id');
  END IF;

  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  SELECT id, customer_id, status, payment_method, service_type, laundry_order_id, laundry_leg
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  v_should_refund := p_do_refund IS TRUE
    AND lower(COALESCE(v_booking.payment_method, '')) = 'wallet';

  IF v_should_refund THEN
    SELECT ABS(wt.amount) INTO v_payment_amount
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON w.id = wt.wallet_id
    WHERE w.user_id = v_booking.customer_id AND wt.type = 'payment' AND wt.amount < 0
      AND wt.related_booking_id = p_booking_id::text
    LIMIT 1;

    SELECT ABS(wt.amount) INTO v_hold_amount
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON w.id = wt.wallet_id
    WHERE w.user_id = v_booking.customer_id AND wt.type = 'hold' AND wt.amount < 0
      AND wt.related_booking_id = p_booking_id::text
    LIMIT 1;

    v_refund_amount := COALESCE(NULLIF(COALESCE(v_payment_amount, 0), 0), COALESCE(v_hold_amount, 0));

    IF v_refund_amount <= 0 THEN
      IF v_booking.service_type = 'laundry' AND v_booking.laundry_leg = 'return' THEN
        v_should_refund := false;
      ELSE
        RETURN jsonb_build_object('success', false, 'error', 'wallet_payment_not_found', 'booking_id', p_booking_id);
      END IF;
    END IF;

    IF v_should_refund THEN
      IF COALESCE(v_payment_amount, 0) <= 0
        AND COALESCE(v_hold_amount, 0) > 0
        AND EXISTS (SELECT 1 FROM public.wallet_transactions wt
                    WHERE wt.related_booking_id = p_booking_id::text AND wt.type = 'release')
      THEN
        RETURN jsonb_build_object('success', false, 'error', 'hold_already_released', 'booking_id', p_booking_id);
      END IF;

      SELECT public.refund_booking_to_customer_wallet(
        p_booking_id, v_refund_amount,
        'คืนเงินจากยกเลิกออเดอร์ #' || LEFT(p_booking_id::text, 8) || ' (Admin)')
      INTO v_refund_result;

      IF COALESCE((v_refund_result->>'success')::boolean, false) IS NOT TRUE
        AND COALESCE(v_refund_result->>'error', '') <> 'already_refunded'
      THEN
        RETURN jsonb_build_object('success', false,
          'error', COALESCE(v_refund_result->>'error', 'wallet_refund_failed'),
          'booking_id', p_booking_id, 'refund_result', v_refund_result);
      END IF;
    END IF;
  END IF;

  IF v_booking.status <> 'cancelled' THEN
    IF v_booking.status <> 'completed' THEN
      v_coupons_released := public._release_booking_coupon(p_booking_id);
    END IF;
    UPDATE public.bookings
    SET status = 'cancelled',
        status_origin = 'jdc',
        cancellation_reason = 'admin_force_cancel: ' || COALESCE(p_reason, ''),
        updated_at = now()
    WHERE id = p_booking_id;
  END IF;

  IF v_booking.service_type = 'laundry' AND v_booking.laundry_order_id IS NOT NULL THEN
    IF v_booking.laundry_leg = 'outbound' THEN
      UPDATE public.laundry_orders
      SET status = 'cancelled', updated_at = now()
      WHERE id = v_booking.laundry_order_id
        AND status IN ('outbound_pending', 'outbound_assigned', 'outbound_picked_up');
    ELSIF v_booking.laundry_leg = 'return' THEN
      UPDATE public.laundry_orders
      SET status = 'ready_for_return', return_booking_id = NULL,
          return_wallet_hold_transaction_id = NULL, updated_at = now()
      WHERE id = v_booking.laundry_order_id
        AND status IN ('return_pending', 'return_assigned', 'return_picked_up');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'cancelled', true,
    'refunded', v_should_refund,
    'refund_amount', CASE WHEN v_should_refund THEN v_refund_amount ELSE 0 END,
    'refund_result', v_refund_result,
    'coupons_released', v_coupons_released
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_force_cancel_booking_with_wallet_refund(uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_force_cancel_booking_with_wallet_refund(uuid, text, boolean) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) TO authenticated, service_role;

-- 5) C3: apply_coupon_atomic คำนวณส่วนลดเองจาก booking --------------------
CREATE OR REPLACE FUNCTION public.apply_coupon_atomic(p_coupon_id uuid, p_user_id uuid, p_booking_id uuid, p_discount_amount numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  c record;
  b record;
  v_user_usage_count int;
  v_base numeric;
  v_order numeric;
  v_fee numeric;
  v_discount numeric;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'COUPON_FORBIDDEN: user mismatch';
  END IF;

  SELECT * INTO c FROM public.coupons WHERE id = p_coupon_id AND is_active = true FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'COUPON_NOT_FOUND: Coupon not found or inactive';
  END IF;

  SELECT id, customer_id, service_type, merchant_id, price, delivery_fee, status
    INTO b
  FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND OR b.customer_id <> p_user_id THEN
    RAISE EXCEPTION 'COUPON_BOOKING_INVALID: booking not found for user';
  END IF;
  IF b.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'COUPON_BOOKING_INVALID: booking already closed';
  END IF;
  IF EXISTS (SELECT 1 FROM public.coupon_usages WHERE booking_id = p_booking_id) THEN
    RAISE EXCEPTION 'COUPON_ALREADY_APPLIED: booking already has a coupon';
  END IF;

  IF c.start_date IS NOT NULL AND now() < c.start_date THEN
    RAISE EXCEPTION 'COUPON_NOT_STARTED: Coupon is not yet valid';
  END IF;
  IF c.end_date IS NOT NULL AND now() > c.end_date THEN
    RAISE EXCEPTION 'COUPON_EXPIRED: Coupon has expired';
  END IF;
  IF c.usage_limit > 0 AND c.used_count >= c.usage_limit THEN
    RAISE EXCEPTION 'COUPON_EXHAUSTED: Coupon usage limit exceeded';
  END IF;
  IF c.per_user_limit > 0 THEN
    SELECT count(*) INTO v_user_usage_count
    FROM public.coupon_usages WHERE coupon_id = p_coupon_id AND user_id = p_user_id;
    IF v_user_usage_count >= c.per_user_limit THEN
      RAISE EXCEPTION 'COUPON_USER_LIMIT: Per-user coupon limit exceeded';
    END IF;
  END IF;
  IF c.service_type IS NOT NULL AND c.service_type <> b.service_type THEN
    RAISE EXCEPTION 'COUPON_SERVICE_MISMATCH: Coupon not valid for this service';
  END IF;
  IF c.merchant_id IS NOT NULL AND c.merchant_id IS DISTINCT FROM b.merchant_id THEN
    RAISE EXCEPTION 'COUPON_MERCHANT_MISMATCH: Coupon not valid for this merchant';
  END IF;

  v_order := GREATEST(COALESCE(b.price, 0), 0);
  v_fee := GREATEST(COALESCE(b.delivery_fee, 0), 0);
  IF c.min_order_amount IS NOT NULL AND v_order < c.min_order_amount THEN
    RAISE EXCEPTION 'COUPON_MIN_ORDER: Order amount below minimum';
  END IF;

  v_base := CASE WHEN c.discount_base::text = 'delivery_fee' THEN v_fee ELSE v_order END;
  v_discount := CASE c.discount_type
    WHEN 'percentage' THEN LEAST(v_base * (COALESCE(c.discount_value, 0) / 100.0),
                                 COALESCE(c.max_discount_amount, 'Infinity'::numeric))
    WHEN 'fixed' THEN LEAST(COALESCE(c.discount_value, 0), v_base)
    WHEN 'free_delivery' THEN v_fee
    ELSE 0 END;
  v_discount := round(GREATEST(COALESCE(v_discount, 0), 0), 2);

  INSERT INTO public.coupon_usages (coupon_id, user_id, booking_id, discount_amount)
  VALUES (p_coupon_id, p_user_id, p_booking_id, v_discount);

  UPDATE public.coupons SET used_count = used_count + 1 WHERE id = p_coupon_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.apply_coupon_atomic(uuid, uuid, uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_coupon_atomic(uuid, uuid, uuid, numeric) TO authenticated, service_role;

-- 6) Guard: client ห้ามปิดงานตรง / แก้คอลัมน์เงิน -----------------------------
CREATE OR REPLACE FUNCTION public.guard_booking_client_writes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') OR public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status = 'completed' THEN
      RAISE EXCEPTION 'booking_status_not_allowed';
    END IF;
    NEW.driver_id := NULL;
    NEW.driver_earnings := NULL;
    NEW.app_earnings := NULL;
    NEW.platform_gp_amount := 0;
    NEW.merchant_net_amount := 0;
    RETURN NEW;
  END IF;

  IF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed' THEN
    RAISE EXCEPTION 'use_complete_booking';
  END IF;

  IF NEW.driver_id IS DISTINCT FROM OLD.driver_id
     AND NOT ((OLD.driver_id IS NULL AND NEW.driver_id = auth.uid())
              OR (OLD.driver_id = auth.uid() AND NEW.driver_id IS NULL)) THEN
    RAISE EXCEPTION 'driver_change_not_allowed';
  END IF;

  NEW.price := OLD.price;
  NEW.delivery_fee := OLD.delivery_fee;
  NEW.food_cost := OLD.food_cost;
  NEW.total_amount := OLD.total_amount;
  NEW.driver_earnings := OLD.driver_earnings;
  NEW.app_earnings := OLD.app_earnings;
  NEW.platform_gp_amount := OLD.platform_gp_amount;
  NEW.merchant_net_amount := OLD.merchant_net_amount;
  NEW.payment_method := OLD.payment_method;
  NEW.customer_id := OLD.customer_id;
  NEW.merchant_id := OLD.merchant_id;
  NEW.service_type := OLD.service_type;
  NEW.gp_system_rate_at_order := OLD.gp_system_rate_at_order;
  NEW.gp_driver_rate_at_order := OLD.gp_driver_rate_at_order;
  NEW.delivery_system_rate_at_order := OLD.delivery_system_rate_at_order;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_booking_client_writes ON public.bookings;
CREATE TRIGGER trg_guard_booking_client_writes
  BEFORE INSERT OR UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_booking_client_writes();

COMMIT;
