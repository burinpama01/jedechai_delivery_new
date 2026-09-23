import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/shop_order.dart';
import '../../../../common/services/shop_service.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../utils/debug_logger.dart';

/// หน้าติดตามออเดอร์ฝากซื้อ
///
///  * เห็นคนขับติ๊กของทีละชิ้นแบบ realtime
///  * ร้านที่ไม่ออกใบเสร็จ: ดูรูปสินค้าแล้วกดยืนยันให้คนขับส่งต่อ
///    ครบ 5 นาทีไม่ยืนยัน ระบบ**ไม่**ยืนยันแทน แค่ขึ้นช่องทางติดต่อคนขับ
///  * ยกเลิกได้จนถึงก่อนคนขับชำระเงินที่ร้าน
class ShopTrackingScreen extends StatefulWidget {
  const ShopTrackingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<ShopTrackingScreen> createState() => _ShopTrackingScreenState();
}

class _ShopTrackingScreenState extends State<ShopTrackingScreen> {
  final _shop = ShopService();
  final _client = Supabase.instance.client;

  RealtimeChannel? _channel;
  RealtimeChannel? _itemsChannel;
  Timer? _ticker;

  bool _loading = true;
  bool _busy = false;
  String _status = 'pending';
  ShopOrder? _order;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
    // นับเวลาสำหรับข้อความ "ยืนยันภายใน N นาที"
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    if (_itemsChannel != null) {
      _client.removeChannel(_itemsChannel!);
    }
    super.dispose();
  }

  bool _reloading = false;

  Future<void> _load() async {
    // realtime ยิงหลาย event พร้อมกันได้ ถ้าปล่อยให้ซ้อนกัน
    // ผลลัพธ์ที่มาถึงทีหลังอาจเป็นข้อมูลเก่ากว่า แล้วทับ state ใหม่
    if (_reloading) return;
    _reloading = true;
    try {
      final booking = await _client
          .from('bookings')
          .select('status')
          .eq('id', widget.bookingId)
          .maybeSingle();

      final order = await _shop.orderByBookingId(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _status = (booking?['status'] as String?) ?? 'pending';
        _order = order;
        _loading = false;
      });
      if (order != null) _subscribeItems(order.id);
    } catch (e) {
      debugLog('❌ โหลดสถานะฝากซื้อไม่สำเร็จ: $e');
      if (mounted) setState(() => _loading = false);
    } finally {
      _reloading = false;
    }
  }

  void _subscribe() {
    _channel = _client
        .channel('shop_track_${widget.bookingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.bookingId,
          ),
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shop_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: widget.bookingId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  /// items ต้อง subscribe แยกเพราะต้องรู้ shop_order_id ก่อน
  /// **ห้าม subscribe โดยไม่ใส่ filter** ไม่งั้นจะรับ event ของออเดอร์คนอื่นทั้งระบบ
  void _subscribeItems(String shopOrderId) {
    if (_itemsChannel != null) return;
    _itemsChannel = _client
        .channel('shop_items_$shopOrderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shop_order_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_order_id',
            value: shopOrderId,
          ),
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // ── actions ──────────────────────────────────────────────────────────

  Future<void> _confirmProof() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final res = await _shop.confirmProof(widget.bookingId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (res['success'] != true) {
      _snack(l10n.shopErrGeneric);
      return;
    }
    await _load();
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: jdc.surface,
        title: Text(l10n.shopCancelConfirmTitle),
        content: Text(_cancelWarningText(l10n)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.shopQuoteBack),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: jdc.danger),
            child: Text(l10n.shopCancelOrder),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final res = await _shop.cancel(widget.bookingId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (res['success'] != true) {
      _snack(res['error'] == 'cannot_cancel_after_purchase'
          ? l10n.shopCancelBlocked
          : l10n.shopErrGeneric);
      return;
    }
    _snack(l10n.shopCancelDone);
    await _load();
  }

  String _money(double v) => '฿${v.toStringAsFixed(2)}';

  /// ข้อความเตือนก่อนยกเลิก
  ///
  /// ตัวเลขค่าปรับมาจาก `fee_config_snapshot` ของออเดอร์นี้ที่ server เก็บไว้
  /// ถ้าอ่านไม่ได้ให้เตือนแบบไม่ระบุตัวเลข ดีกว่าแสดงเลขที่อาจไม่ตรงกับที่ถูกหักจริง
  String _cancelWarningText(AppLocalizations l10n) {
    if (_status != 'shopping') return l10n.shopCancelWarnFree;
    final fee = _order?.cancelFeeIfShopping;
    if (fee == null) return l10n.shopCancelWarnAfterPurchase;
    return l10n.shopCancelWarnFee(_money(fee));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _canCancel =>
      _status == 'pending' || _status == 'accepted' || _status == 'shopping';

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    final order = _order;

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(l10n.shopTrackTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _statusCard(jdc, l10n),
                  const SizedBox(height: 14),
                  if (order != null && order.needsCustomerConfirm)
                    _proofCard(jdc, l10n, order),
                  if (order != null) ...[
                    _itemsCard(jdc, l10n, order),
                    const SizedBox(height: 14),
                    _summaryCard(jdc, l10n, order),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: (_canCancel && !_loading)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: OutlinedButton(
                  onPressed: _busy ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(JdcTouch.button),
                    side: BorderSide(color: jdc.dangerLine),
                    foregroundColor: jdc.dangerInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(JdcRadius.small),
                    ),
                  ),
                  child: Text(l10n.shopCancelOrder),
                ),
              ),
            )
          : null,
    );
  }

  Widget _statusCard(JdcColors jdc, AppLocalizations l10n) {
    String title;
    String? hint;
    IconData icon;

    switch (_status) {
      case 'pending':
        title = l10n.shopTrackFindingDriver;
        hint = l10n.shopTrackFindingDriverHint;
        icon = Icons.search_rounded;
        break;
      case 'accepted':
        title = l10n.shopTrackAccepted;
        icon = Icons.two_wheeler_rounded;
        break;
      case 'shopping':
        title = l10n.shopTrackShopping;
        icon = Icons.shopping_basket_rounded;
        break;
      case 'receipt_review':
        title = l10n.shopTrackReceiptReview;
        icon = Icons.photo_camera_rounded;
        break;
      case 'purchased':
        title = l10n.shopTrackPurchased;
        icon = Icons.check_circle_rounded;
        break;
      case 'delivering':
      case 'in_transit':
        title = l10n.shopTrackDelivering;
        icon = Icons.local_shipping_rounded;
        break;
      case 'completed':
        title = l10n.shopTrackCompleted;
        icon = Icons.done_all_rounded;
        break;
      case 'cancelled':
        title = l10n.shopTrackCancelled;
        icon = Icons.cancel_rounded;
        break;
      default:
        title = _status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: jdc.brandSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: jdc.link),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: jdc.text)),
                if (_order != null) ...[
                  const SizedBox(height: 2),
                  Text(_order!.storeName,
                      style: TextStyle(fontSize: 12.5, color: jdc.muted)),
                ],
                if (hint != null) ...[
                  const SizedBox(height: 6),
                  Text(hint,
                      style: TextStyle(
                          fontSize: 12, height: 1.5, color: jdc.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// รูปสินค้าจากคนขับ + ปุ่มยืนยัน (ร้านที่ไม่ออกใบเสร็จ)
  Widget _proofCard(JdcColors jdc, AppLocalizations l10n, ShopOrder order) {
    final sentAt = order.proofSentAt;
    final waited =
        sentAt == null ? 0 : DateTime.now().difference(sentAt).inMinutes;
    // ครบเวลาแล้วไม่ปิดกั้นอะไร แค่เพิ่มช่องทางติดต่อคนขับ
    final showContact = waited >= 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.brandLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.shopProofTitle,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: jdc.text)),
          const SizedBox(height: 4),
          Text(l10n.shopProofConfirmHint,
              style: TextStyle(fontSize: 12, height: 1.5, color: jdc.muted)),
          const SizedBox(height: 10),
          if (order.proofUrls.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: order.proofUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                  child: AppNetworkImage(
                    imageUrl: order.proofUrls[i],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (order.actualGoodsAmount != null)
            Row(
              children: [
                Expanded(
                  child: Text(l10n.shopSummaryGoodsActual,
                      style: TextStyle(fontSize: 13, color: jdc.muted)),
                ),
                Text(
                  _money(order.actualGoodsAmount!),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: jdc.text),
                ),
              ],
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _confirmProof,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(JdcTouch.button),
              backgroundColor: jdc.cta,
              foregroundColor: jdc.onCta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
            ),
            child: Text(l10n.shopProofConfirm,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (!showContact) ...[
            const SizedBox(height: 6),
            Text(l10n.shopProofWaitMinutes(5),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: jdc.muted)),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: jdc.infoSoft,
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
              child: Text(
                l10n.shopProofContactDriver,
                style: TextStyle(fontSize: 12, color: jdc.infoInk),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemsCard(JdcColors jdc, AppLocalizations l10n, ShopOrder order) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.shopItemsHeader,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: jdc.text)),
              ),
              Text(
                '${l10n.shopSubtotalSoFar} ${_money(order.boughtSubtotal)}',
                style: TextStyle(fontSize: 12.5, color: jdc.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in order.items) _itemRow(jdc, l10n, item),
        ],
      ),
    );
  }

  Widget _itemRow(JdcColors jdc, AppLocalizations l10n, ShopOrderItem item) {
    late final IconData icon;
    late final Color color;
    late final String statusText;

    switch (item.status) {
      case 'bought':
        icon = Icons.check_circle_rounded;
        color = jdc.successInk;
        statusText = l10n.shopItemStatusBought;
        break;
      case 'substituted':
        icon = Icons.swap_horiz_rounded;
        color = jdc.infoInk;
        statusText = l10n.shopItemStatusSubstituted;
        break;
      case 'unavailable':
        icon = Icons.remove_circle_outline_rounded;
        color = jdc.dangerInk;
        statusText = l10n.shopItemStatusUnavailable;
        break;
      default:
        icon = Icons.radio_button_unchecked_rounded;
        color = jdc.dim;
        statusText = l10n.shopItemStatusPending;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.quantityText == null || item.quantityText!.isEmpty
                      ? item.name
                      : '${item.name} · ${item.quantityText}',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: jdc.text,
                    decoration: item.isUnavailable
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  item.substituteName == null
                      ? statusText
                      : '$statusText · ${item.substituteName}',
                  style: TextStyle(fontSize: 11.5, color: color),
                ),
              ],
            ),
          ),
          if (item.actualPrice != null)
            Text(_money(item.actualPrice!),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: jdc.text)),
        ],
      ),
    );
  }

  Widget _summaryCard(JdcColors jdc, AppLocalizations l10n, ShopOrder order) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.shopSummaryTitle,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: jdc.text)),
          const SizedBox(height: 8),
          _line(jdc, l10n.shopQuoteHold, _money(order.holdAmount)),
          if (order.actualGoodsAmount != null)
            _line(jdc, l10n.shopSummaryGoodsActual,
                _money(order.actualGoodsAmount!)),
          _line(jdc, l10n.shopQuoteDelivery, _money(order.deliveryFee)),
          _line(jdc, l10n.shopQuoteService, _money(order.serviceFee)),
          if (order.farPickupFee > 0)
            _line(jdc, l10n.shopQuoteFarPickup, _money(order.farPickupFee)),
          if (order.cancelFee != null && order.cancelFee! > 0)
            _line(jdc, l10n.shopCancelOrder, _money(order.cancelFee!),
                danger: true),
          if (order.totalAmount != null) ...[
            Divider(color: jdc.line, height: 18),
            _line(jdc, l10n.shopSummaryTotal, _money(order.totalAmount!),
                bold: true),
          ],
          if (order.refundAmount != null && order.refundAmount! > 0)
            _line(jdc, l10n.shopSummaryRefund, _money(order.refundAmount!),
                success: true),
        ],
      ),
    );
  }

  Widget _line(
    JdcColors jdc,
    String label,
    String value, {
    bool bold = false,
    bool success = false,
    bool danger = false,
  }) {
    final color = danger
        ? jdc.dangerInk
        : success
            ? jdc.successInk
            : jdc.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: jdc.muted)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
