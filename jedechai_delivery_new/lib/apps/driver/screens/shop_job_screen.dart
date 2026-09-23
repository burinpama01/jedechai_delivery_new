import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';
import '../../../common/models/shop_order.dart';
import '../../../common/services/image_picker_service.dart';
import '../../../common/services/shop_service.dart';
import '../../../common/services/storage_service.dart';
import '../../../common/widgets/shop_ref_image.dart';

/// หน้างานฝากซื้อของคนขับ
///
/// ลำดับ: ถึงร้าน -> ติ๊กของทีละชิ้น + กรอกราคาจากบิล -> ถ่ายหลักฐาน
/// -> ยืนยันซื้อ -> (ร้านไม่มีใบเสร็จ: รอลูกค้ายืนยัน) -> นำส่ง -> ปิดงาน
///
/// ยอดเงินทั้งหมด server เป็นคนคิด แอปส่งได้แค่ "ราคาต่อชิ้นที่อ่านจากบิล"
class ShopJobScreen extends StatefulWidget {
  const ShopJobScreen({
    super.key,
    required this.bookingId,
    required this.initialStatus,
  });

  final String bookingId;
  final String initialStatus;

  @override
  State<ShopJobScreen> createState() => _ShopJobScreenState();
}

class _ShopJobScreenState extends State<ShopJobScreen> {
  final _shop = ShopService();

  late String _status = widget.initialStatus;
  ShopOrder? _order;
  bool _loading = true;
  bool _busy = false;

  /// สถานะที่คนขับแก้อยู่ในเครื่อง (ยังไม่ส่งขึ้น server)
  final Map<int, String> _draftStatus = {};
  final Map<int, TextEditingController> _priceControllers = {};
  final Map<int, TextEditingController> _substituteControllers = {};

  final List<File> _proofFiles = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    for (final c in _substituteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final order = await _shop.orderByBookingId(widget.bookingId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _loading = false;
      if (order != null) {
        for (final item in order.items) {
          _draftStatus.putIfAbsent(item.lineNo, () => item.status);
          _priceControllers.putIfAbsent(
            item.lineNo,
            () => TextEditingController(
              text: item.actualPrice == null
                  ? ''
                  : item.actualPrice!.toStringAsFixed(0),
            ),
          );
          _substituteControllers.putIfAbsent(
            item.lineNo,
            () => TextEditingController(text: item.substituteName ?? ''),
          );
        }
      }
    });
  }

  String _money(double v) => '฿${v.toStringAsFixed(2)}';

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// แปลง error code จาก server เป็นข้อความที่คนขับเข้าใจ
  String _errText(AppLocalizations l10n, Map<String, dynamic> res) {
    switch (res['error']?.toString()) {
      case 'too_far_from_store':
        final m = res['allowed_m'];
        return '${l10n.shopDrvTooFar} · ${l10n.shopDrvAllowedRadius(m?.toString() ?? '-')}';
      case 'driver_location_stale':
        return l10n.shopDrvLocationStale;
      case 'driver_location_unknown':
        return l10n.shopDrvLocationUnknown;
      case 'exceeds_hold':
        return l10n.shopDrvExceedsHold;
      case 'items_still_pending':
        return l10n.shopDrvItemsPending;
      case 'nothing_bought':
        return l10n.shopDrvNothingBought;
      case 'new_driver_budget_limit':
        return l10n.shopDrvNewDriverLimit;
      case 'already_taken':
        return l10n.shopDrvAlreadyTaken;
      case 'not_your_job':
        return l10n.shopDrvNotYourJob;
      case 'proof_required':
        return l10n.shopDrvProofRequired;
      default:
        return l10n.shopErrGeneric;
    }
  }

  // ── ถึงร้าน ───────────────────────────────────────────────────────────

  /// ระยะที่ยอมให้กด "ถึงร้าน" ฝั่งแอป — ผ่อนเท่ากับ geofence เดิมของแอปคนขับ
  /// (100 ม. + เผื่อความคลาดเคลื่อน GPS สูงสุด 50 ม.)
  /// server ตรวจซ้ำอีกชั้นและเป็นตัวตัดสินจริง ตรงนี้แค่กันไม่ให้ยิงไปแล้วโดนปฏิเสธ
  static const double _arriveRadiusMeters = 100;
  static const double _arriveAccuracyTolerance = 50;

  Future<bool> _isNearStore(ShopOrder order) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final meters = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        order.storeLat,
        order.storeLng,
      );
      final allowed = _arriveRadiusMeters +
          pos.accuracy.clamp(0.0, _arriveAccuracyTolerance);
      return meters <= allowed;
    } catch (_) {
      // อ่านตำแหน่งไม่ได้ -> ปล่อยให้ server เป็นคนตัดสิน ไม่บล็อกที่แอป
      return true;
    }
  }

  Future<void> _arrive({bool selfReported = false}) async {
    final l10n = AppLocalizations.of(context)!;
    final order = _order;

    if (!selfReported && order != null) {
      setState(() => _busy = true);
      final near = await _isNearStore(order);
      if (!mounted) return;
      if (!near) {
        setState(() => _busy = false);
        _snack(l10n.shopDrvTooFar);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _busy = true);
    final res = await _shop.driverArrivedAtStore(
      widget.bookingId,
      selfReported: selfReported,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (res['success'] != true) {
      _snack(_errText(l10n, res));
      return;
    }
    setState(() => _status = 'shopping');
    await _load();
  }

  // ── เช็คลิสต์ ─────────────────────────────────────────────────────────

  double get _subtotal {
    double sum = 0;
    for (final entry in _draftStatus.entries) {
      if (entry.value != 'bought' && entry.value != 'substituted') continue;
      final raw = _priceControllers[entry.key]?.text.trim() ?? '';
      sum += double.tryParse(raw) ?? 0;
    }
    return sum;
  }

  bool get _hasPending => _draftStatus.values.any((s) => s == 'pending');

  List<Map<String, dynamic>> _itemsPayload() {
    return _draftStatus.entries.map((e) {
      final status = e.value;
      final priceRaw = _priceControllers[e.key]?.text.trim() ?? '';
      final price = priceRaw.isEmpty ? null : double.tryParse(priceRaw);
      final sub = _substituteControllers[e.key]?.text.trim() ?? '';
      return <String, dynamic>{
        'line_no': e.key,
        'status': status,
        // ส่งเป็นตัวเลข ไม่ใช่ string ที่ผู้ใช้พิมพ์ดิบ ๆ
        // (server ยังตรวจซ้ำและเป็นคนรวมยอดจริงอยู่ดี)
        if (status == 'bought' || status == 'substituted') 'actual_price': price,
        if (status == 'substituted' && sub.isNotEmpty) 'substitute_name': sub,
      };
    }).toList();
  }

  Future<bool> _saveItems({bool silent = false}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final res = await _shop.driverUpdateItems(widget.bookingId, _itemsPayload());
    if (!mounted) return false;
    setState(() => _busy = false);

    if (res['success'] != true) {
      _snack(_errText(l10n, res));
      return false;
    }
    if (!silent) _snack(l10n.shopDrvSaved);
    await _load();
    return true;
  }

  // ── หลักฐาน ──────────────────────────────────────────────────────────

  Future<void> _addPhoto() async {
    final file = await ImagePickerService.showImageSourceDialog(context);
    if (file == null || !mounted) return;
    setState(() => _proofFiles.add(file));
  }

  Future<void> _confirmPurchase() async {
    final l10n = AppLocalizations.of(context)!;

    if (_proofFiles.isEmpty) {
      _snack(l10n.shopDrvProofRequired);
      return;
    }
    if (_hasPending) {
      _snack(l10n.shopDrvItemsPending);
      return;
    }

    // บันทึกรายการก่อนเสมอ ไม่งั้น server จะคิดยอดจากข้อมูลเก่า
    if (!await _saveItems(silent: true)) return;
    if (!mounted) return;

    setState(() => _uploading = true);
    final paths = <String>[];
    for (final file in _proofFiles) {
      final path = await StorageService.uploadPrivateFile(
        file: file,
        path: widget.bookingId,
        bucketName: ShopService.receiptBucket,
        metadata: {'booking_id': widget.bookingId},
      );
      if (path == null) {
        if (!mounted) return;
        setState(() => _uploading = false);
        _snack(l10n.shopDrvUploadFailed);
        return;
      }
      paths.add(path);
    }

    if (!mounted) return;
    final res = await _shop.markPurchased(widget.bookingId, paths);
    if (!mounted) return;
    setState(() => _uploading = false);

    if (res['success'] != true) {
      _snack(_errText(l10n, res));
      return;
    }
    setState(() => _status = res['status']?.toString() ?? 'purchased');
    await _load();
  }

  // ── นำส่ง / ปิดงาน ────────────────────────────────────────────────────

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final res = await _shop.completeBooking(widget.bookingId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (res['success'] != true) {
      _snack(_errText(l10n, res));
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    final order = _order;

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(l10n.shopDrvJobTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : order == null
              ? Center(child: Text(l10n.shopErrGeneric))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _headerCard(jdc, l10n, order),
                    const SizedBox(height: 14),
                    if (_status == 'accepted') _arriveCard(jdc, l10n),
                    if (_status == 'shopping') ...[
                      _checklistCard(jdc, l10n, order),
                      const SizedBox(height: 14),
                      _proofCard(jdc, l10n, order),
                    ],
                    if (_status == 'receipt_review')
                      _waitingCustomerCard(jdc, l10n),
                    if (_status == 'purchased' || _status == 'delivering')
                      _deliverCard(jdc, l10n, order),
                  ],
                ),
    );
  }

  Widget _card(JdcColors jdc, {required Widget child, Color? border}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(color: border ?? jdc.line),
        ),
        child: child,
      );

  Widget _headerCard(JdcColors jdc, AppLocalizations l10n, ShopOrder order) =>
      _card(
        jdc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront_rounded, color: jdc.link),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: jdc.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.shopDrvBudget} ${_money(order.budgetCap)}',
                    style: TextStyle(fontSize: 13, color: jdc.muted),
                  ),
                ),
                Text(
                  '${order.items.length} ${l10n.shopDrvItemsCount}',
                  style: TextStyle(fontSize: 13, color: jdc.muted),
                ),
              ],
            ),
            if (order.customerNote != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: jdc.sunken,
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                ),
                child: Text(order.customerNote!,
                    style: TextStyle(fontSize: 12.5, color: jdc.text)),
              ),
            ],
          ],
        ),
      );

  /// ปุ่มถึงร้าน + ทางออกเมื่อ GPS เพี้ยน
  Widget _arriveCard(JdcColors jdc, AppLocalizations l10n) => _card(
        jdc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _busy ? null : () => _arrive(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(JdcTouch.button),
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                ),
              ),
              child: Text(l10n.shopDrvArrived,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _busy ? null : () => _arrive(selfReported: true),
              child: Text(l10n.shopDrvSelfReport,
                  style: TextStyle(fontSize: 13, color: jdc.muted)),
            ),
            Text(
              l10n.shopDrvSelfReportHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.5, color: jdc.dim),
            ),
          ],
        ),
      );

  Widget _checklistCard(
      JdcColors jdc, AppLocalizations l10n, ShopOrder order) {
    final over = _subtotal > order.budgetCap;
    return _card(
      jdc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.shopDrvChecklist,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: jdc.text)),
          const SizedBox(height: 8),
          for (final item in order.items) _itemRow(jdc, l10n, item),
          Divider(color: jdc.line, height: 20),
          Row(
            children: [
              Expanded(
                child: Text(l10n.shopDrvSubtotal,
                    style: TextStyle(fontSize: 13, color: jdc.muted)),
              ),
              Text(
                _money(_subtotal),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: over ? jdc.dangerInk : jdc.text,
                ),
              ),
            ],
          ),
          if (over)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.shopDrvOverBudget,
                  style: TextStyle(fontSize: 12, color: jdc.dangerInk)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.shopDrvBudgetLeft(_money(order.budgetCap - _subtotal)),
                style: TextStyle(fontSize: 12, color: jdc.muted),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () => _saveItems(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(JdcTouch.minTarget),
              side: BorderSide(color: jdc.line),
              foregroundColor: jdc.text,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
            ),
            child: Text(l10n.shopDrvSaveItems),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(JdcColors jdc, AppLocalizations l10n, ShopOrderItem item) {
    final status = _draftStatus[item.lineNo] ?? 'pending';
    final showPrice = status == 'bought' || status == 'substituted';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: jdc.sunken,
        borderRadius: BorderRadius.circular(JdcRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.quantityText == null || item.quantityText!.isEmpty
                ? item.name
                : '${item.name} · ${item.quantityText}',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: jdc.text),
          ),
          if (item.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(item.note!,
                  style: TextStyle(fontSize: 11.5, color: jdc.muted)),
            ),
          if (item.refImagePath != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ShopRefImage(
                path: item.refImagePath!,
                label: l10n.shopDrvRefPhoto,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _statusChip(jdc, item.lineNo, 'bought', l10n.shopDrvMarkBought,
                  jdc.successInk, jdc.successSoft),
              _statusChip(jdc, item.lineNo, 'unavailable',
                  l10n.shopDrvMarkUnavailable, jdc.dangerInk, jdc.dangerSoft),
              _statusChip(jdc, item.lineNo, 'substituted',
                  l10n.shopDrvMarkSubstituted, jdc.infoInk, jdc.infoSoft),
            ],
          ),
          if (showPrice) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceControllers[item.lineNo],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.shopDrvPriceLabel,
                      isDense: true,
                      filled: true,
                      fillColor: jdc.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(JdcRadius.field),
                        borderSide: BorderSide(color: jdc.line),
                      ),
                    ),
                  ),
                ),
                if (status == 'substituted') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _substituteControllers[item.lineNo],
                      decoration: InputDecoration(
                        labelText: l10n.shopDrvSubstituteLabel,
                        isDense: true,
                        filled: true,
                        fillColor: jdc.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(JdcRadius.field),
                          borderSide: BorderSide(color: jdc.line),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(JdcColors jdc, int lineNo, String value, String label,
      Color ink, Color soft) {
    final active = (_draftStatus[lineNo] ?? 'pending') == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          // กดซ้ำ = ยกเลิกการติ๊ก กลับเป็นยังไม่ได้ซื้อ
          _draftStatus[lineNo] = active ? 'pending' : value;
          if (_draftStatus[lineNo] == 'unavailable' ||
              _draftStatus[lineNo] == 'pending') {
            _priceControllers[lineNo]?.clear();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? soft : jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.chip),
          border: Border.all(color: active ? ink : jdc.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? ink : jdc.text,
          ),
        ),
      ),
    );
  }

  Widget _proofCard(JdcColors jdc, AppLocalizations l10n, ShopOrder order) {
    final isReceipt = order.proofMode == 'receipt';
    return _card(
      jdc,
      border: jdc.brandLine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isReceipt ? l10n.shopDrvProofStepReceipt : l10n.shopDrvProofStepPhoto,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: jdc.text),
          ),
          const SizedBox(height: 4),
          Text(
            isReceipt ? l10n.shopDrvProofHintReceipt : l10n.shopDrvProofHintPhoto,
            style: TextStyle(fontSize: 12, height: 1.5, color: jdc.muted),
          ),
          const SizedBox(height: 10),
          if (_proofFiles.isNotEmpty)
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _proofFiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(JdcRadius.small),
                      child: Image.file(_proofFiles[i],
                          width: 92, height: 92, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _proofFiles.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: jdc.danger,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded,
                              size: 14, color: jdc.onCta),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _addPhoto,
            icon: const Icon(Icons.add_a_photo_rounded, size: 18),
            label: Text(l10n.shopDrvAddPhoto),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(JdcTouch.minTarget),
              side: BorderSide(color: jdc.line),
              foregroundColor: jdc.text,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: (_uploading || _busy || _subtotal > order.budgetCap)
                ? null
                : _confirmPurchase,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(JdcTouch.button),
              backgroundColor: jdc.cta,
              foregroundColor: jdc.onCta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
            ),
            child: _uploading
                ? Text(l10n.shopDrvUploading)
                : Text(l10n.shopDrvConfirmPurchase,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _waitingCustomerCard(JdcColors jdc, AppLocalizations l10n) => _card(
        jdc,
        child: Column(
          children: [
            Icon(Icons.hourglass_top_rounded, size: 34, color: jdc.infoInk),
            const SizedBox(height: 8),
            Text(l10n.shopDrvWaitingCustomer,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: jdc.text)),
            const SizedBox(height: 4),
            Text(l10n.shopDrvWaitingCustomerHint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: jdc.muted)),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _load,
              child: Text(l10n.shopStoreRetry),
            ),
          ],
        ),
      );

  Widget _deliverCard(JdcColors jdc, AppLocalizations l10n, ShopOrder order) =>
      _card(
        jdc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (order.totalAmount != null)
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.shopSummaryTotal,
                        style: TextStyle(fontSize: 13, color: jdc.muted)),
                  ),
                  Text(_money(order.totalAmount!),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: jdc.text)),
                ],
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _complete,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(JdcTouch.button),
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                ),
              ),
              child: Text(l10n.shopDrvComplete,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
