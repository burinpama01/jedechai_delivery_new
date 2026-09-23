import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/shop_quote.dart';

/// สิ่งที่ลูกค้าเลือกจาก dialog สรุปราคา
enum ShopQuoteAction { confirm, topup, refresh, cancel }

/// Dialog สรุปราคาก่อนยืนยันสั่ง
///
/// ข้อกำหนด (แผน v4 หัวข้อ 5):
///  * เป็น modal ทับหน้าเดิม ไม่เปลี่ยนหน้า
///  * แสดงทุกบรรทัดราคา ไม่ซ่อนใน "ค่าบริการอื่น ๆ"
///  * ยอด "กันไว้จาก Wallet" ต้องเด่นที่สุด
///  * คำเตือนยกเลิกแสดงเป็นจำนวนเงินจริง ไม่ใช่แค่เปอร์เซ็นต์
///  * ปุ่มยืนยันติดอยู่ล่างเสมอ คำเตือนอยู่เหนือปุ่ม
///
/// ตัวเลขทุกตัวมาจาก server ทั้งหมด — widget นี้ไม่คำนวณอะไรเลย
Future<ShopQuoteAction?> showShopQuoteDialog(
  BuildContext context, {
  required ShopQuote quote,
  required String storeName,
  required String Function(double) money,
}) {
  return showDialog<ShopQuoteAction>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _ShopQuoteDialog(
      quote: quote,
      storeName: storeName,
      money: money,
    ),
  );
}

class _ShopQuoteDialog extends StatelessWidget {
  const _ShopQuoteDialog({
    required this.quote,
    required this.storeName,
    required this.money,
  });

  final ShopQuote quote;
  final String storeName;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    final expired = quote.isExpired;

    return Dialog(
      backgroundColor: jdc.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JdcRadius.sheet),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: JdcBreakpoints.formMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── หัว ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.shopQuoteTitle,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: jdc.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: jdc.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).pop(ShopQuoteAction.cancel),
                    icon: Icon(Icons.close_rounded, color: jdc.muted),
                    tooltip: l10n.shopQuoteBack,
                  ),
                ],
              ),
            ),

            // ── เนื้อหาเลื่อนได้ ปุ่มยังติดล่างเสมอ ───────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _row(jdc, l10n.shopQuoteGoods, money(quote.budgetCap)),
                    _row(
                      jdc,
                      '${l10n.shopQuoteDelivery} · ${quote.distanceKm.toStringAsFixed(1)} กม.',
                      money(quote.deliveryFee),
                    ),
                    _row(jdc, l10n.shopQuoteService, money(quote.serviceFee)),

                    // ค่าวิ่งไกลแสดงเฉพาะเมื่อเกิดขึ้นจริง พร้อมบอกเหตุผล
                    if (quote.farPickupFee > 0)
                      _row(
                        jdc,
                        l10n.shopQuoteFarPickup,
                        money(quote.farPickupFee),
                        sub: quote.nearestDriverKm == null
                            ? null
                            : l10n.shopFarPickupReason(
                                quote.nearestDriverKm!.toStringAsFixed(1)),
                      ),

                    Divider(color: jdc.line, height: 20),

                    // ยอดที่กันไว้ — ต้องเด่นที่สุด
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.shopQuoteHold,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: jdc.text,
                            ),
                          ),
                        ),
                        Text(
                          money(quote.holdAmount),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: jdc.successInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _row(jdc, l10n.shopQuoteWallet, money(quote.walletBalance),
                        dim: true),
                    if (!quote.sufficient)
                      _row(
                        jdc,
                        l10n.shopQuoteShortfall,
                        money(quote.shortfall),
                        danger: true,
                      ),

                    const SizedBox(height: 10),
                    Text(
                      l10n.shopQuoteRefundNote,
                      style: TextStyle(
                          fontSize: 12, height: 1.5, color: jdc.muted),
                    ),

                    if (quote.driverCountInRadius > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.two_wheeler_rounded,
                              size: 14, color: jdc.successInk),
                          const SizedBox(width: 6),
                          Text(
                            l10n.shopDriverCount(quote.driverCountInRadius),
                            style: TextStyle(
                                fontSize: 12, color: jdc.successInk),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── คำเตือนยกเลิก อยู่เหนือปุ่มเสมอ ───────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: jdc.dangerSoft,
                borderRadius: BorderRadius.circular(JdcRadius.small),
                border: Border.all(color: jdc.dangerLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.shopCancelWarnFee(money(quote.cancelFeeIfShopping)),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: jdc.dangerInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.shopCancelWarnAfterPurchase,
                    style: TextStyle(
                        fontSize: 12, height: 1.5, color: jdc.dangerInk),
                  ),
                  const SizedBox(height: 4),
                  // บอกด้วยว่ายกเลิกฟรีได้เมื่อไหร่ ไม่ใช่เขียนแต่ข้อเสีย
                  Text(
                    l10n.shopCancelWarnFree,
                    style: TextStyle(fontSize: 12, color: jdc.muted),
                  ),
                ],
              ),
            ),

            if (expired)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  l10n.shopQuoteExpired,
                  style: TextStyle(fontSize: 12.5, color: jdc.dangerInk),
                ),
              ),

            // ── ปุ่ม ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(ShopQuoteAction.cancel),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(JdcTouch.button),
                        side: BorderSide(color: jdc.line),
                        foregroundColor: jdc.text,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(JdcRadius.small),
                        ),
                      ),
                      child: Text(l10n.shopQuoteBack),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        expired
                            ? ShopQuoteAction.refresh
                            : (quote.sufficient
                                ? ShopQuoteAction.confirm
                                : ShopQuoteAction.topup),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(JdcTouch.button),
                        backgroundColor: jdc.cta,
                        foregroundColor: jdc.onCta,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(JdcRadius.small),
                        ),
                      ),
                      child: Text(
                        expired
                            ? l10n.shopQuoteRefresh
                            : (quote.sufficient
                                ? l10n.shopQuoteConfirm
                                : '${l10n.shopQuoteTopupAndOrder} ${money(quote.shortfall)}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    JdcColors jdc,
    String label,
    String value, {
    String? sub,
    bool dim = false,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: danger ? jdc.dangerInk : (dim ? jdc.muted : jdc.text),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: danger ? FontWeight.w700 : FontWeight.w600,
                  color: danger ? jdc.dangerInk : (dim ? jdc.muted : jdc.text),
                ),
              ),
            ],
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub,
                  style: TextStyle(fontSize: 11.5, color: jdc.muted)),
            ),
        ],
      ),
    );
  }
}
