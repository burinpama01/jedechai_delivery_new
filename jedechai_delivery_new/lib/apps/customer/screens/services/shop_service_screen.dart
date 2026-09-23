import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/saved_address.dart';
import '../../../../common/models/shop_order.dart';
import '../../../../common/models/shop_quote.dart';
import '../../../../common/models/shop_store.dart';
import '../../../../common/services/geocoding_service.dart';
import '../../../../common/services/image_picker_service.dart';
import '../../../../common/services/location_service.dart';
import '../../../../common/services/shop_service.dart';
import '../../../../utils/debug_logger.dart';
import '../customer_wallet_screen.dart';
import 'delivery_map_picker_screen.dart';
import 'saved_addresses_screen.dart';
import 'shop_quote_dialog.dart';
import 'shop_store_request_screen.dart';
import 'shop_tracking_screen.dart';

/// หน้าสั่งฝากซื้อ/ฝากหิ้ว
///
/// ลำดับ: ที่อยู่ส่ง -> เลือกร้าน (หมุดที่แอดมินตั้ง ในรัศมีจากที่อยู่ส่ง) -> พิมพ์รายการ -> วงเงิน
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

  /// โหมดที่อยู่จัดส่ง — ใช้ชุดเดียวกับหน้าสั่งอาหาร ('current' | 'pin' | 'saved')
  /// เพื่อให้ลูกค้าเจอฟอร์มหน้าตาเดียวกันทุกบริการ — null = ยังไม่เลือก
  /// (ร้านวัดรัศมีจากที่อยู่นี้ จึงต้องเลือกก่อนถึงจะแสดงร้าน)
  String? _deliveryMode;
  bool _resolvingAddress = false;

  /// เปิดรับคำขอเพิ่มร้านอยู่ไหม (แอดมินปิดได้)
  bool _storeRequestEnabled = false;

  /// ร้านที่เลือกไว้ไม่อยู่ในผลค้นหารอบล่าสุด (รัศมีวัดจากที่อยู่จัดส่ง)
  /// เกิดได้เมื่อลูกค้าเลือกร้านแล้วค่อยเปลี่ยนที่อยู่ไปไกล — server เป็นคนตัดสิน
  /// ว่าร้านไหนอยู่ในรัศมี แอปแค่ดูว่าร้านยังอยู่ในรายการที่ส่งกลับมาหรือไม่
  bool _storeOutOfRange = false;

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
    // ร้านต้องวัดรัศมีจากที่อยู่จัดส่ง -> ยังไม่เลือกที่อยู่ก็ยังไม่โหลดร้าน
    if (_destLat != null && _destLng != null) await _loadStores();
    await _loadStoreRequestFlag();
  }

  Future<void> _loadStoreRequestFlag() async {
    final enabled = await _shop.storeRequestEnabled();
    if (!mounted) return;
    setState(() => _storeRequestEnabled = enabled);
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
    // รูปอยู่ในโฟลเดอร์ชั่วคราว ระบบอาจล้างไปแล้วระหว่างที่ออกไปเติมเงิน
    for (final item in items) {
      if (item.hasImage && !File(item.localImagePath!).existsSync()) {
        item.localImagePath = null;
      }
    }
    setState(() {
      if (items.isNotEmpty) _items = items;
      _pendingDraftStoreId = draft['store_id'] as String?;
      _destLat = (draft['dest_lat'] as num?)?.toDouble();
      _destLng = (draft['dest_lng'] as num?)?.toDouble();
      _destAddress = (draft['dest_address'] as String?) ?? '';
      // draft ที่มีที่อยู่ติดมาแล้ว = ลูกค้าเคยเลือกเอง ใช้ต่อได้เลย
      if (_destLat != null && _destLng != null) {
        _deliveryMode = 'pin';
      }
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
      // รัศมีวัดจากจุดส่งของ (ร้านต้องใกล้ปลายทาง ไม่ใช่ใกล้ตัวลูกค้าตอนกดสั่ง)
      // ลูกค้าต้องเลือกที่อยู่ก่อนเสมอ ไม่เดาจาก GPS ให้
      final centerLat = _destLat;
      final centerLng = _destLng;
      if (centerLat == null || centerLng == null) {
        if (!mounted || token != _storeRequestToken) return;
        setState(() => _loadingStores = false);
        return;
      }

      final stores = await _shop.nearbyStores(
        lat: centerLat,
        lng: centerLng,
        // ดึงทุกหมวดเสมอ แล้วกรองหมวดตอนแสดงผล — ไม่งั้นร้านที่เลือกไว้แต่ต่างหมวด
        // จะหายจากผล แล้วแยกไม่ออกว่าหายเพราะนอกรัศมีหรือเพราะตัวกรอง
        category: null,
      );

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
        final selected = _selectedStore;
        if (selected != null) {
          ShopStore? fresh;
          for (final s in stores) {
            if (s.id == selected.id) {
              fresh = s;
              break;
            }
          }
          // ได้ระยะใหม่จากที่อยู่ล่าสุดด้วย; ถ้าไม่เจอ = อยู่นอกรัศมี
          if (fresh != null) _selectedStore = fresh;
          _storeOutOfRange = fresh == null;
        }
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
    final cat = _categoryFilter;
    if (q.isEmpty && cat == null) return _stores;
    return _stores
        .where((s) => cat == null || s.category == cat)
        .where((s) =>
            q.isEmpty ||
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
    if (_storeOutOfRange) return false;
    if (_items.every((i) => i.isBlank)) return false;
    if (_destLat == null || _destLng == null) return false;
    final b = _budgetValue;
    return b != null && b >= _minBudget && b <= _maxBudget;
  }

  // ── ที่อยู่ส่ง ─────────────────────────────────────────────────────────

  /// แปลงพิกัดปัจจุบันเป็นข้อความที่อยู่ (ให้ลูกค้าเห็นว่าจะส่งไปที่ไหนจริง)
  Future<void> _resolveCurrentAddress(double lat, double lng) async {
    if (mounted) setState(() => _resolvingAddress = true);
    final addr = await GeocodingService.getAddressFromCoordinates(lat, lng);
    if (!mounted) return;
    setState(() {
      _resolvingAddress = false;
      // ลูกค้าอาจเปลี่ยนไปปักหมุดระหว่างรอ -> อย่าเขียนทับ
      if (_deliveryMode == 'current' && addr != null && addr.isNotEmpty) {
        _destAddress = addr;
      }
    });
  }

  /// ตัวเลือก 1: ตำแหน่งปัจจุบัน
  Future<void> _useCurrentLocation() async {
    final prevMode = _deliveryMode;
    final prevAddress = _destAddress;
    setState(() {
      _deliveryMode = 'current';
      _destAddress = '';
    });
    final pos = await LocationService.getCurrentLocation(context: context);
    if (!mounted) return;
    if (pos == null) {
      // ขอตำแหน่งไม่ได้ -> คืนตัวเลือกเดิม ไม่ให้ขึ้นว่าเลือก "ปัจจุบัน" ทั้งที่ไม่มีพิกัด
      setState(() {
        _deliveryMode = prevMode;
        _destAddress = prevAddress;
      });
      _snack(AppLocalizations.of(context)!.shopStoreLocationNeeded);
      return;
    }
    setState(() {
      _myLat = pos.latitude;
      _myLng = pos.longitude;
      _destLat = pos.latitude;
      _destLng = pos.longitude;
    });
    unawaited(_loadStores());
    await _resolveCurrentAddress(pos.latitude, pos.longitude);
  }

  /// ตัวเลือก 2: ปักหมุดบนแผนที่
  Future<void> _openMapPicker() async {
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
      _deliveryMode = 'pin';
      _destLat = lat;
      _destLng = lng;
      _destAddress = result['address']?.toString() ?? '';
    });
    await _loadStores();
  }

  /// ตัวเลือก 3: ที่อยู่ที่บันทึกไว้
  Future<void> _openSavedAddresses() async {
    final result = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(
        builder: (_) => const SavedAddressesScreen(pickMode: true),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _deliveryMode = 'saved';
      _destLat = result.latitude;
      _destLng = result.longitude;
      _destAddress = '${result.name} — ${result.address}';
    });
    await _loadStores();
  }

  // ── รูปตัวอย่างต่อรายการ ──────────────────────────────────────────────

  /// เลือกรูป (กล้อง/คลัง) — ImagePickerService ย่อเหลือไม่เกิน 1024px
  /// และบีบอัดไฟล์ที่เกิน 500KB ให้แล้ว ก่อนจะถึงขั้นอัปโหลด
  Future<void> _pickItemImage(int index) async {
    final file = await ImagePickerService.showImageSourceDialog(context);
    if (file == null || !mounted || index >= _items.length) return;
    setState(() => _items[index].localImagePath = file.path);
  }

  void _removeItemImage(int index) {
    setState(() => _items[index].localImagePath = null);
  }

  // ── คำขอเพิ่มร้าน ────────────────────────────────────────────────────

  Future<void> _openStoreRequest() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShopStoreRequestScreen(
          initialPosition: (_myLat != null && _myLng != null)
              ? LatLng(_myLat!, _myLng!)
              : null,
          initialName: _searchController.text,
        ),
      ),
    );
    if (sent == true && mounted) _searchController.clear();
  }

  Future<void> _showMyStoreRequests() async {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    final rows = await _shop.myStoreRequests();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: jdc.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: rows.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Text(l10n.shopStoreEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: jdc.muted)),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(l10n.shopReqMine,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: jdc.text)),
                  const SizedBox(height: 8),
                  for (final r in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r['name']?.toString() ?? '',
                          style: TextStyle(color: jdc.text)),
                      subtitle: (r['admin_note']?.toString() ?? '').isEmpty
                          ? null
                          : Text(r['admin_note'].toString(),
                              style: TextStyle(color: jdc.muted)),
                      trailing: _requestStatusPill(jdc, l10n, r['status']),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _requestStatusPill(JdcColors jdc, AppLocalizations l10n, Object? s) {
    switch (s?.toString()) {
      case 'approved':
        return _pill(jdc, l10n.shopReqStatusApproved, false);
      case 'rejected':
        return _pill(jdc, l10n.shopReqStatusRejected, true);
      default:
        return Text(l10n.shopReqStatusPending,
            style: TextStyle(fontSize: 12, color: jdc.muted));
    }
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
        setState(() {
          _selectedStore = null;
          _storeOutOfRange = false;
        });
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
    if (_destLat == null || _destLng == null) return;

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

    final bookingId = res['booking_id']?.toString();
    if (bookingId == null) {
      await _shop.clearDraft();
      return;
    }

    // รูปตัวอย่างอัปโหลดได้หลังมี booking_id เท่านั้น (policy ตรวจจาก path)
    // ล้มก็ไม่ย้อนออเดอร์ — แค่บอกลูกค้าให้คุยกับคนขับในแชทแทน
    if (_items.any((i) => !i.isBlank && i.hasImage)) {
      if (mounted) {
        setState(() => _placing = true);
        _snack(l10n.shopItemPhotoUploading);
      }
      bool ok;
      try {
        ok = await _shop.uploadItemImages(bookingId: bookingId, items: _items);
      } catch (e) {
        debugLog('❌ อัปโหลดรูปตัวอย่าง: $e');
        ok = false;
      }
      if (mounted) {
        setState(() => _placing = false);
        if (!ok) _snack(l10n.shopItemPhotoUploadFailed);
      }
    }

    await _shop.clearDraft();
    if (!mounted) return;

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
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(color: jdc.text),
        iconTheme: IconThemeData(color: jdc.text),
        elevation: 0,
        // โหมดสว่าง surface (ขาว) กับ paper ต่างกันนิดเดียว header เลยกลืนไปกับพื้น
        // -> ขีดเส้นใต้แบบเดียวกับหน้าที่อยู่ + ปิด tint ที่ M3 ใส่ตอนเลื่อน
        shape: Border(bottom: BorderSide(color: jdc.line)),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ที่อยู่ก่อน: รัศมีร้านวัดจากที่อยู่จัดส่ง
            _sectionTitle(jdc, l10n.shopStepDelivery),
            _addressCard(jdc, l10n),
            const SizedBox(height: 18),
            _sectionTitle(jdc, l10n.shopStepStore),
            if (_destLat == null || _destLng == null)
              _needAddressCard(jdc, l10n)
            else
              _storePicker(jdc, l10n),
            const SizedBox(height: 18),

            if (_selectedStore != null) ...[
              _sectionTitle(jdc, l10n.shopStepItems),
              _itemsEditor(jdc, l10n),
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
              onPressed: () => setState(() {
                _selectedStore = null;
                _storeOutOfRange = false;
              }),
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
              Icons.error_outline_rounded,
              color: jdc.muted,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.shopErrGeneric,
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
        if (_storeRequestEnabled) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _openStoreRequest,
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: Text(l10n.shopStoreRequestCta, textAlign: TextAlign.center),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(JdcTouch.minTarget),
              side: BorderSide(color: jdc.brandLine),
              foregroundColor: jdc.link,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _showMyStoreRequests,
              child: Text(l10n.shopReqMine,
                  style: TextStyle(fontSize: 12.5, color: jdc.muted)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _catChip(JdcColors jdc, String label, String? value) {
    final active = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        // กรองในเครื่องจากผลที่มีอยู่แล้ว (ผลทุกหมวดมาจาก server รอบเดียว)
        onTap: () => setState(() => _categoryFilter = value),
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
        setState(() {
          _selectedStore = s;
          _storeOutOfRange = false;
        });
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
      // ผูก state ของช่องกรอกกับตัว item ไม่ใช่ลำดับ — ลบบรรทัดกลางแล้วข้อความไม่สลับแถว
      key: ObjectKey(item),
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
          const SizedBox(height: 8),
          _itemPhoto(jdc, l10n, index),
        ],
      ),
    );
  }

  /// แนบรูปตัวอย่าง (ไม่บังคับ)
  Widget _itemPhoto(JdcColors jdc, AppLocalizations l10n, int index) {
    final item = _items[index];
    if (!item.hasImage) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _pickItemImage(index),
          icon: Icon(Icons.add_a_photo_outlined, size: 18, color: jdc.link),
          label: Text(l10n.shopItemPhoto,
              style: TextStyle(fontSize: 13, color: jdc.link)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, JdcTouch.minTarget),
          ),
        ),
      );
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(JdcRadius.small),
          child: Image.file(
            File(item.localImagePath!),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            cacheWidth: 168,
            errorBuilder: (_, __, ___) => Container(
              width: 56,
              height: 56,
              color: jdc.sunken,
              child: Icon(Icons.broken_image_outlined, color: jdc.muted),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            l10n.shopItemPhotoHint,
            style: TextStyle(fontSize: 11.5, height: 1.4, color: jdc.muted),
          ),
        ),
        IconButton(
          tooltip: l10n.shopItemPhotoAdd,
          onPressed: () => _pickItemImage(index),
          icon: Icon(Icons.autorenew_rounded, color: jdc.muted, size: 20),
        ),
        IconButton(
          tooltip: l10n.shopItemPhotoRemove,
          onPressed: () => _removeItemImage(index),
          icon: Icon(Icons.delete_outline_rounded,
              color: jdc.dangerInk, size: 20),
        ),
      ],
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

  /// แทนรายการร้านจนกว่าจะเลือกที่อยู่จัดส่ง
  Widget _needAddressCard(JdcColors jdc, AppLocalizations l10n) => _card(
        jdc,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(Icons.storefront_outlined, color: jdc.muted, size: 32),
              const SizedBox(height: 8),
              Text(
                l10n.shopStoreNeedAddress,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: jdc.muted),
              ),
            ],
          ),
        ),
      );

  // ── ที่อยู่ + วงเงิน ───────────────────────────────────────────────────

  /// ฟอร์มที่อยู่จัดส่ง — ชุดเดียวกับหน้าสั่งอาหาร (ตำแหน่งปัจจุบัน / ปักหมุด / ที่บันทึกไว้)
  Widget _addressCard(JdcColors jdc, AppLocalizations l10n) {
    final hasAddress = _destAddress.isNotEmpty;
    return _card(
      jdc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _addressOption(jdc,
              icon: Icons.my_location,
              label: l10n.foodAddressCurrentLocation,
              selected: _deliveryMode == 'current',
              onTap: _useCurrentLocation),
          const SizedBox(height: 8),
          _addressOption(jdc,
              icon: Icons.pin_drop,
              label: l10n.foodAddressPinOnMap,
              selected: _deliveryMode == 'pin',
              onTap: _openMapPicker),
          const SizedBox(height: 8),
          _addressOption(jdc,
              icon: Icons.bookmark_outline,
              label: l10n.foodAddressSaved,
              selected: _deliveryMode == 'saved',
              onTap: _openSavedAddresses),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasAddress ? jdc.successSoft : jdc.sunken,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: hasAddress ? jdc.successLine : jdc.line),
            ),
            child: Row(
              children: [
                if (_resolvingAddress && !hasAddress)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    hasAddress
                        ? Icons.check_circle
                        : Icons.location_searching_rounded,
                    size: 16,
                    color: hasAddress ? jdc.successInk : jdc.muted,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasAddress
                        ? _destAddress
                        : (_destLat != null && _destLng != null)
                            ? '${_destLat!.toStringAsFixed(5)}, ${_destLng!.toStringAsFixed(5)}'
                            : l10n.shopAddressPickFirst,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasAddress ? jdc.successInk : jdc.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_storeOutOfRange) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: jdc.dangerSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: jdc.dangerLine),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.wrong_location_outlined,
                      size: 16, color: jdc.dangerInk),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.shopStoreOutOfRange,
                      style: TextStyle(fontSize: 12, color: jdc.dangerInk),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _addressOption(
    JdcColors jdc, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: JdcTouch.minTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? jdc.brand : jdc.line,
            width: selected ? 2 : 1,
          ),
          color: selected ? jdc.brand.withValues(alpha: 0.05) : jdc.sunken,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? jdc.brand : jdc.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? jdc.brand : jdc.text,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 20, color: jdc.brand),
          ],
        ),
      ),
    );
  }

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
