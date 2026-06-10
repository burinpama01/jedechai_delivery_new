-- Repair legacy admin refund rows that credited customer wallets without an
-- original wallet payment ledger. Keep audit rows, but remove them from usable
-- wallet value by marking the old row invalid and inserting a balancing entry.

CREATE TEMP TABLE tmp_invalid_customer_refunds ON COMMIT DROP AS
SELECT
  wt.id,
  wt.wallet_id,
  wt.amount,
  wt.description,
  wt.related_booking_id
FROM public.wallet_transactions wt
WHERE wt.type = 'refund'
  AND wt.amount > 0
  AND COALESCE(wt.description, '') LIKE 'คืนเงินจากยกเลิกออเดอร์ #% (Admin)'
  AND (
    wt.related_booking_id IS NULL
    OR NOT EXISTS (
      SELECT 1
      FROM public.wallet_transactions p
      WHERE p.wallet_id = wt.wallet_id
        AND p.related_booking_id = wt.related_booking_id
        AND p.type = 'payment'
        AND p.amount < 0
    )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.wallet_transactions rev
    WHERE rev.wallet_id = wt.wallet_id
      AND rev.type = 'invalid_refund_reversal'
      AND rev.description LIKE '%' || wt.id::text || '%'
  );

INSERT INTO public.wallet_transactions (
  wallet_id,
  amount,
  type,
  description,
  related_booking_id
)
SELECT
  wallet_id,
  -amount,
  'invalid_refund_reversal',
  'ยกเลิกยอดคืนเงินที่ไม่ใช่ Wallet tx ' || id::text || ': ' || COALESCE(description, ''),
  related_booking_id
FROM tmp_invalid_customer_refunds;

UPDATE public.wallet_transactions wt
SET
  type = 'invalid_refund',
  description = 'ไม่นับเป็น Wallet: ' || COALESCE(wt.description, '')
FROM tmp_invalid_customer_refunds r
WHERE wt.id = r.id;

UPDATE public.wallets w
SET
  balance = w.balance - r.total_amount,
  updated_at = now()
FROM (
  SELECT wallet_id, SUM(amount) AS total_amount
  FROM tmp_invalid_customer_refunds
  GROUP BY wallet_id
) r
WHERE w.id = r.wallet_id;
