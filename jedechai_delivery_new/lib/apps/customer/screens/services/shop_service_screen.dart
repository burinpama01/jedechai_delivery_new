import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/shop_order.dart';
import '../../../../common/models/shop_quote.dart';
import '../../../../common/models/shop_store.dart';
import '../../../../common/services/location_service.dart';
import '../../../../common/services/shop_service.dart';
import '../../../../utils/debug_logger.dart';
import '../customer_wallet_screen.dart';
import 'delivery_map_picker_screen.dart';
import 'shop_quote_dialog.dart';
import 'shop_tracking_screen.dart';

/// หน้าสั่งฝากซื้อ/ฝากหิ้ว
///
/// ลำดับ: เลือกร้าน (หมุดที่แอดมินตั้ง) -> พิมพ์รายการ -> ที่อยู่ส่ง -> วงเงิน
/// -> ขอราคาจาก server -> dialog สรุปราคา -> ยืนยัน
///
/// ราคาทุกบรรทัดมาจาก RPC `shop_quote` แอปไม่คำนวณเอง
class ShopServiceScreen extends StatefulWidget {
  const ShopServiceScreen({super.key});

  @override
  State<ShopServiceScreen> createState() => _ShopServiceScreenState();
}

class _ShopServiceScreenState extends State<ShopServiceScreen> {
  final _shop = ShopService();
  final _budgetController = TextEditingController();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();

  bool _loadingStores = true;
  String? _storeError;
  List<ShopStore> _stores = const [];
  String? _categoryFilter;

  ShopStore? _selectedStore;
  List<ShopDraftItem> _items = [ShopDraftItem()];

  double? _destLat;
  double? _destLng;
  String _destAddress = '';

  double? _myLat;
  double? _myLng;

  /// ร้านที่ค้างอยู่ใน draft — เลือกคืนให้อัตโนมัติหลังโหลดรายการร้านเสร็จ
  /// ไม่งั้น draft ที่กู้มาจะใช้ไม่ได้จริง เพราะทุก section ซ่อนอยู่จนกว่าจะเลือกร้าน
  String? _pendingDraftStoreId;

  /// กันผลลัพธ์ของการกดหมวดครั้งก่อนมาทับครั้งล่าสุด (กดรัว ๆ แล้วได้หมวดผิด)
  int _storeRequestToken = 0;

  bool _quoting = false;
  bool _placing = false;

  ShopLimits _limits = const ShopLimits();
  int get _maxItems => _limits.maxItems;
  double get _minBudget => _limits.minBudget;
  double get _maxBudget => _limits.maxBudget;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadLimits();
    await _restoreDraft();
    await _loadStores();
  }

  /// ดึงขีดจำกัดที่แอดมินตั้งไว้ เพื่อให้ UI ตรงกับที่ server จะยอมรับ
  /// (ถ้าอ่านไม่ได้ก็ใช้ค่าเริ่มต้น — server บังคับจริงอีกชั้นอยู่แล้ว)
  Future<void> _loadLimits() async {
    final limits = await _shop.limits();
    if (!mounted) return;
    setState(() => _limits = limits);
  }

  // ── draft ────────────────────────────────────────────────────────────
  // จำเป็นเพราะตอนไปเติมเงินต้องออกจากแอป ระบบอาจคืน memory ระหว่างนั้น

  Future<void> _restoreDraft() async {
    final draft = await _shop.loadDraft();
    if (draft == null || !mounted) return;

    final items = ShopService.draftItemsFrom(draft);
    setState(() {
      if (items.isNotEmpty) _items = items;
      _pendingDraftStoreId = draft['store_id'] as String?;
      _destLat = (draft['dest_lat'] as num?)?.toDouble();
      _destLng = (draft['dest_lng'] as num?)?.toDouble();
      _destAddress = (draft['dest_address'] as String?) ?? '';
      final budget = (draft['budget_cap'] as num?)?.toDouble();
      if (budget != null && budget > 0) {
        _budgetController.text = budget.toStringAsFixed(0);
      }
      _noteController.text = (draft['note'] as String?) ?? '';
    });

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shopDraftRestored)),
      );
    }
  }

  Future<void> _saveDraft() async {
    final store = _selectedStore;
    if (store == null) return;
    await _shop.saveDraft(
      storeId: store.id,
      storeName: store.name,
      items: _items,
      budgetCap: _budgetValue ?? 0,
      destLat: _destLat,
      destLng: _destLng,
      destAddress: _destAddress,
      note: _noteController.text,
    );
  }

  // ── ร้าน ─────────────────────────────────────────────────────────────

  Future<void> _loadStores() async {
    final token = ++_storeRequestToken;
    setState(() {
      _loadingStores = true;
      _storeError = null;
    });

    try {
      final pos = await LocationService.getCurrentLocation(context: context);
      if (pos == null) {
        if (!mounted || token != _storeRequestToken) return;
        setState(() {
          _loadingStores = false;
          _storeError = 'location';
        });
        return;
      }
      _myLat = pos.latitude;
      _myLng = pos.longitude;

      final stores = await _shop.nearbyStores(
        lat: pos.latitude,
        lng: pos.longitude,
        category: _categoryFilter,
      );

      // ยังไม่ได้เลือกที่อยู่ส่ง -> ใช้ตำแหน่งปัจจุบันเป็นค่าเริ่มต้น
      _destLat ??= pos.latitude;
      _destLng ??= pos.longitude;

      if (!mounted || token != _storeRequestToken) return;

      // draft ค้างอยู่ -> เลือกร้านเดิมคืนให้ ถ้ายังเปิดอยู่
      ShopStore? restored;
      final draftStoreId = _pendingDraftStoreId;
      if (draftStoreId != null) {
        for (final s in stores) {
          if (s.id == draftStoreId && s.isOpenNow) {
            restored = s;
            break;
          }
        }
        _pendingDraftStoreId = null;
      }

      setState(() {
        _stores = stores;
        _loadingStores = false;
        if (restored != null) _selectedStore = restored;
      });
    } catch (e) {
      debugLog('❌ โหลดร้านฝากซื้อไม่สำเร็จ: $e');
      if (!mounted || token != _storeRequestToken) return;
      setState(() {
        _loadingStores = false;
        _storeError = 'generic';
      });
    }
  }

  List<ShopStore> get _visibleStores {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _stores;
    return _stores
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.address ?? '').toLowerCase().contains(q))
        .toList();
  }

  // ── รายการของ ────────────────────────────────────────────────────────

  void _addItem() {
    if (_items.length >= _maxItems) return;
    setState(() => _items.add(ShopDraftItem()));
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      if (_items.isEmpty) _items.add(ShopDraftItem());
    });
  }

  double? get _budgetValue {
    final raw = _budgetController.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool get _canQuote {
    if (_selectedStore == null) return false;
    if (!_selectedStore!.isOpenNow) return false;
    if (_items.every((i) => i.isBlank)) return false;
    if (_destLat == null || _destLng == null) return false;
    final b = _budgetValue;
    return b != null && b >= _minBudget && b <= _maxBudget;
  }

  // ── ที่อยู่ส่ง ─────────────────────────────────────────────────────────

  Future<void> _pickAddress() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => DeliveryMapPickerScreen(
          initialPosition: (_destLat != null && _destLng != null)
              ? LatLng(_destLat!, _destLng!)
              : (_myLat != null && _myLng != null)
                  ? LatLng(_myLat!, _myLng!)
                  : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final lat = (result['lat'] as num?)?.toDouble();
    final lng = (result['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    setState(() {
      _destLat = lat;
      _destLng = lng;
      _destAddress = result['address']?.toString() ?? '';
    });
  }

  // ── ขอราคา + ยืนยัน ───────────────────────────────────────────────────

  String _money(double v) => '฿${v.toStringAsFixed(2)}';

  String _quoteErrorText(AppLocalizations l10n, ShopQuote q) {
    switch (q.error) {
      case 'no_driver_available':
        return l10n.shopErrNoDriver;
      case 'store_closed':
        return l10n.shopErrStoreClosed;
      case 'shop_disabled':
        return l10n.shopErrShopDisabled;
      case 'budget_below_min':
        return l10n.shopBudgetRange(
          _money(q.minBudget ?? _minBudget),
          _money(_maxBudget),
        );
      case 'budget_above_max':
        return l10n.shopBudgetRange(
          _money(_minBudget),
          _money(q.maxBudget ?? _maxBudget),
        );
      default:
        return l10n.shopErrGeneric;
    }
  }

  Future<void> _startQuoteFlow() async {
    final l10n = AppLocalizations.of(context)!;
    final store = _selectedStore;
    final budget = _budgetValue;
    if (store == null || budget == null || _destLat == null || _destLng == null) {
      return;
    }

    setState(() => _quoting = true);
    await _saveDraft();

    ShopQuote quote;
    try {
      quote = await _shop.quote(
        storeId: store.id,
        budgetCap: budget,
        destLat: _destLat!,
        destLng: _destLng!,
      );
    } catch (e) {
      debugLog('❌ shop_quote: $e');
      quote = const ShopQuote(ok: false, error: 'rpc_failed');
    }

    if (!mounted) return;
    setState(() => _quoting = false);

    if (!quote.ok) {
      _snack(_quoteErrorText(l10n, quote));
      // ร้านเพิ่งปิด -> รีเฟรชรายการร้านให้ตรงความจริง
      if (quote.error == 'store_closed') {
        setState(() => _selectedStore = null);
        await _loadStores();
      }
      return;
    }

    final action = await showShopQuoteDialog(
      context,
      quote: quote,
      storeName: store.name,
      money: _money,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case ShopQuoteAction.cancel:
        return;
      case ShopQuoteAction.refresh:
        return _startQuoteFlow();
      case ShopQuoteAction.topup:
        await _saveDraft();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomerWalletScreen()),
        );
        // กลับมาแล้วต้องขอราคาใหม่เสมอ คนขับ/ร้านอาจเปลี่ยนไประหว่างนั้น
        if (!mounted) return;
        return _startQuoteFlow();
      case ShopQuoteAction.confirm:
        return _placeOrder();
    }
  }

  Future<void> _placeOrder() async {
    final l10n = AppLocalizations.of(context)!;
    final store = _selectedStore;
    final budget = _budgetValue;
    if (store == null || budget == null) return;

    setState(() => _placing = true);

    final res = await _shop.createBooking(
      storeId: store.id,
      budgetCap: budget,
      destLat: _destLat!,
      destLng: _destLng!,
      destAddress: _destAddress,
      items: _items,
      note: _noteController.text,
    );

    if (!mounted) return;
    setState(() => _placing = false);

    if (res['success'] != true) {
      final err = res['error']?.toString();
      String msg;
      switch (err) {
        case 'no_driver_available':
          msg = l10n.shopErrNoDriver;
          break;
        case 'store_closed':
          msg = l10n.shopErrStoreClosed;
          break;
        case 'shop_disabled':
          msg = l10n.shopErrShopDisabled;
          break;
        case 'insufficient_balance':
          // ราคาเปลี่ยนระหว่างทาง -> ขอราคาใหม่ให้ลูกค้าเห็นก่อน
          msg = l10n.shopQuoteExpired;
          break;
        default:
          msg = l10n.shopErrGeneric;
      }
      _snack(msg);
      return;
    }

    await _shop.clearDraft();
    final bookingId = res['booking_id']?.toString();
    if (bookingId == null || !mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ShopTrackingScreen(bookingId: bookingId),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(l10n.shopSvcTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _sectionTitle(jdc, l10n.shopStepStore),
            _storePicker(jdc, l10n),
            const SizedBox(height: 18),

            if (_selectedStore != null) ...[
              _sectionTitle(jdc, l10n.shopStepItems),
              _itemsEditor(jdc, l10n),
              const SizedBox(height: 18),
              _sectionTitle(jdc, l10n.shopStepDelivery),
              _addressCard(jdc, l10n),
              const SizedBox(height: 18),
              _sectionTitle(jdc, l10n.shopStepBudget),
              _budgetCard(jdc, l10n),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _selectedStore == null
          ? null
          // หมายเหตุ: ห้ามใช้ JdcContentFrame ใน bottomNavigationBar
          // (บทเรียนแถบตะกร้ายืดเต็มความสูง)
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: (_canQuote && !_quoting && !_placing)
                      ? _startQuoteFlow
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(JdcTouch.button),
                    backgroundColor: jdc.cta,
                    foregroundColor: jdc.onCta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(JdcRadius.small),
                    ),
                  ),
                  child: (_quoting || _placing)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          l10n.shopGetQuote,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(JdcColors jdc, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: jdc.text),
        ),
      );

  Widget _card(JdcColors jdc, {required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(color: jdc.line),
        ),
        child: child,
      );

  // ── ร้าน ─────────────────────────────────────────────────────────────

  Widget _storePicker(JdcColors jdc, AppLocalizations l10n) {
    final selected = _selectedStore;
    if (selected != null) {
      return _card(
        jdc,
        child: Row(
          children: [
            _storeIcon(jdc, selected.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selected.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: jdc.text)),
                  const SizedBox(height: 2),
                  Text(
                    l10n.shopStoreDistance(
                        selected.distanceKm.toStringAsFixed(1)),
                    style: TextStyle(fontSize: 12, color: jdc.muted),
                  ),
                  if (!selected.issuesReceipt) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.shopStoreNoReceiptHint,
                      style: TextStyle(fontSize: 11.5, color: jdc.muted),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedStore = null),
              child: Text(l10n.shopStoreChange),
            ),
          ],
        ),
      );
    }

    if (_loadingStores) {
      return _card(
        jdc,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_storeError != null) {
      return _card(
        jdc,
        child: Column(
          children: [
            Icon(
              _storeError == 'location'
                  ? Icons.location_off_rounded
                  : Icons.error_outline_rounded,
              color: jdc.muted,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              _storeError == 'location'
                  ? l10n.shopStoreLocationNeeded
                  : l10n.shopErrGeneric,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: jdc.muted),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _loadStores,
              child: Text(l10n.shopStoreRetry),
            ),
          ],
        ),
      );
    }

    final visible = _visibleStores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.shopStoreSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: jdc.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(JdcRadius.field),
              borderSide: BorderSide(color: jdc.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(JdcRadius.field),
              borderSide: BorderSide(color: jdc.line),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _catChip(jdc, l10n.shopStoreAll, null),
              _catChip(jdc, l10n.shopCatGrocery, 'grocery'),
              _catChip(jdc, l10n.shopCatMall, 'mall'),
              _catChip(jdc, l10n.shopCatMarket, 'market'),
              _catChip(jdc, l10n.shopCatConvenience, 'convenience'),
              _catChip(jdc, l10n.shopCatPharmacy, 'pharmacy'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          _card(
            jdc,
            child: Column(
              children: [
                Icon(Icons.storefront_rounded, size: 36, color: jdc.dim),
                const SizedBox(height: 10),
                Text(l10n.shopStoreEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: jdc.text)),
                const SizedBox(height: 4),
                Text(l10n.shopStoreEmptyHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: jdc.muted)),
              ],
            ),
          )
        else
          ...visible.map((s) => _storeTile(jdc, l10n, s)),
      ],
    );
  }

  Widget _catChip(JdcColors jdc, String label, String? value) {
    final active = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _categoryFilter = value);
          _loadStores();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? jdc.brandSoft : jdc.surface,
            borderRadius: BorderRadius.circular(JdcRadius.chip),
            border: Border.all(color: active ? jdc.brandLine : jdc.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? jdc.brandOnSoft : jdc.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _storeIcon(JdcColors jdc, String category) {
    IconData icon;
    switch (category) {
      case 'mall':
        icon = Icons.local_mall_rounded;
        break;
      case 'market':
        icon = Icons.shopping_basket_rounded;
        break;
      case 'convenience':
        icon = Icons.local_convenience_store_rounded;
        break;
      case 'pharmacy':
        icon = Icons.medical_services_rounded;
        break;
      default:
        icon = Icons.storefront_rounded;
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: jdc.brandSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: jdc.link, size: 22),
    );
  }

  /// การ์ดร้าน — ร้านปิดต้องกดไม่ได้จริง ไม่ใช่แค่ทำให้จาง
  /// (server เช็คซ้ำอีกชั้นตอนสร้างออเดอร์)
  Widget _storeTile(JdcColors jdc, AppLocalizations l10n, ShopStore s) {
    final closed = !s.isOpenNow;
    final content = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
      ),
      child: Row(
        children: [
          _storeIcon(jdc, s.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: jdc.text),
                      ),
                    ),
                    _pill(
                      jdc,
                      closed ? l10n.shopStoreClosed : l10n.shopStoreOpen,
                      closed,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.shopStoreDistance(s.distanceKm.toStringAsFixed(1)),
                  style: TextStyle(fontSize: 12, color: jdc.muted),
                ),
                if (closed && s.nextOpenAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.shopStoreNextOpen(_formatNextOpen(s.nextOpenAt!)),
                      style: TextStyle(fontSize: 11.5, color: jdc.dangerInk),
                    ),
                  ),
                if (!s.issuesReceipt)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.shopStoreNoReceipt,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: jdc.infoInk),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (closed) {
      // ปิดอยู่ = กดไม่ได้ ไม่ผูก onTap เลย
      return Opacity(opacity: 0.55, child: content);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedStore = s);
      },
      child: content,
    );
  }

  String _formatNextOpen(DateTime dt) {
    final now = DateTime.now();
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) return hm;
    return '${dt.day}/${dt.month} $hm';
  }

  Widget _pill(JdcColors jdc, String text, bool danger) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: danger ? jdc.dangerSoft : jdc.successSoft,
          borderRadius: BorderRadius.circular(JdcRadius.chip),
          border:
              Border.all(color: danger ? jdc.dangerLine : jdc.successLine),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: danger ? jdc.dangerInk : jdc.successInk,
          ),
        ),
      );

  // ── รายการของ ────────────────────────────────────────────────────────

  Widget _itemsEditor(JdcColors jdc, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _items.length; i++) _itemRow(jdc, l10n, i),
        const SizedBox(height: 4),
        if (_items.length < _maxItems)
          OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.shopItemAdd),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(JdcTouch.minTarget),
              side: BorderSide(color: jdc.line),
              foregroundColor: jdc.text,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
            ),
          )
        else
          Text(
            l10n.shopMaxItems(_maxItems),
            style: TextStyle(fontSize: 12, color: jdc.muted),
          ),
      ],
    );
  }

  Widget _itemRow(JdcColors jdc, AppLocalizations l10n, int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item.name,
                  onChanged: (v) => item.name = v,
                  decoration: _dec(jdc, l10n.shopItemName, l10n.shopItemNameHint),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.quantity,
                  onChanged: (v) => item.quantity = v,
                  decoration: _dec(jdc, l10n.shopItemQty, l10n.shopItemQtyHint),
                ),
              ),
              if (_items.length > 1)
                IconButton(
                  tooltip: l10n.shopItemRemove,
                  onPressed: () => _removeItem(index),
                  icon: Icon(Icons.close_rounded, color: jdc.muted, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: item.note,
            onChanged: (v) => item.note = v,
            decoration: _dec(jdc, l10n.shopItemNote, l10n.shopItemNoteHint),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(JdcColors jdc, String label, String hint) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: jdc.sunken,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JdcRadius.field),
          borderSide: BorderSide(color: jdc.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JdcRadius.field),
          borderSide: BorderSide(color: jdc.line),
        ),
      );

  // ── ที่อยู่ + วงเงิน ───────────────────────────────────────────────────

  Widget _addressCard(JdcColors jdc, AppLocalizations l10n) => _card(
        jdc,
        child: Row(
          children: [
            Icon(Icons.location_on_rounded, color: jdc.link),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _destAddress.isEmpty ? l10n.shopPickAddress : _destAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: _destAddress.isEmpty ? jdc.muted : jdc.text,
                ),
              ),
            ),
            TextButton(
              onPressed: _pickAddress,
              child: Text(l10n.shopStoreChange),
            ),
          ],
        ),
      );

  Widget _budgetCard(JdcColors jdc, AppLocalizations l10n) => _card(
        jdc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // กัน '.' ซ้ำ ('500..00') ที่ทำให้ parse ไม่ผ่านแล้วปุ่มกดไม่ได้เงียบ ๆ
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: _dec(jdc, l10n.shopBudgetLabel, '฿'),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.shopBudgetRange(_money(_minBudget), _money(_maxBudget)),
              style: TextStyle(fontSize: 12, color: jdc.muted),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.shopBudgetHelp,
              style: TextStyle(fontSize: 12, height: 1.5, color: jdc.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: _dec(jdc, l10n.shopNoteLabel, l10n.shopNoteHint),
            ),
          ],
        ),
      );
}
