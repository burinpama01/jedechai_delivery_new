import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/debug_logger.dart';
import '../models/shop_order.dart';
import '../models/shop_quote.dart';
import '../models/shop_store.dart';
import 'auth_service.dart';
import 'storage_service.dart';

/// ShopService — บริการฝากซื้อ/ฝากหิ้ว
///
/// หลักการ:
///  * ราคาและยอดเงินทุกตัวมาจาก RPC ฝั่ง server แอปแค่แสดงผล
///  * ร้านมาจากหมุดที่แอดมินตั้งเท่านั้น
///  * draft เก็บในเครื่อง ไม่สร้างแถวใน DB จนกว่าลูกค้าจะกดยืนยัน
class ShopService {
  final SupabaseClient _client = Supabase.instance.client;

  static const _draftKey = 'shop_draft_v1';

  // ── ขีดจำกัดจากฝั่งแอดมิน ───────────────────────────────────────────────

  /// อ่านค่าขีดจำกัดที่แอดมินตั้งไว้ (หน้า Settings) เพื่อให้ UI สอดคล้องกับ server
  ///
  /// server เป็นคนบังคับจริงอยู่แล้ว ค่าพวกนี้ใช้เพื่อ **ไม่ให้ลูกค้ากรอกไปแล้วโดนปฏิเสธ**
  /// ถ้าอ่านไม่ได้ให้ใช้ค่า fallback แทน ห้ามทำให้หน้าจอใช้งานไม่ได้
  Future<ShopLimits> limits() async {
    try {
      final rows = await _client
          .from('system_config')
          .select('key, value')
          .inFilter('key', const [
        'shop_min_budget',
        'shop_max_budget',
        'shop_max_items',
        'shop_budget_buffer_percent',
      ]);

      final map = <String, String>{};
      for (final r in (rows as List)) {
        final k = r['key']?.toString();
        if (k != null) map[k] = r['value']?.toString() ?? '';
      }

      double num(String key, double fallback) {
        final v = double.tryParse((map[key] ?? '').trim());
        return (v == null || v <= 0) ? fallback : v;
      }

      return ShopLimits(
        minBudget: num('shop_min_budget', 100),
        maxBudget: num('shop_max_budget', 5000),
        maxItems: num('shop_max_items', 30).round(),
        budgetBufferPercent: num('shop_budget_buffer_percent', 15),
      );
    } catch (e) {
      debugLog('⚠️ อ่านขีดจำกัดฝากซื้อไม่สำเร็จ ใช้ค่าเริ่มต้น: $e');
      return const ShopLimits();
    }
  }

  /// บริการฝากซื้อเปิดอยู่ไหม — ใช้ซ่อน/แสดงทางเข้าในหน้าแรก
  /// อ่านพลาดให้ถือว่าปิดไว้ก่อน (ปลอดภัยกว่าแสดงบริการที่ยังไม่พร้อม)
  Future<bool> isEnabled() async {
    try {
      final row = await _client
          .from('system_config')
          .select('value')
          .eq('key', 'shop_enabled')
          .maybeSingle();
      final raw = (row?['value'] ?? '').toString().trim().toLowerCase();
      return raw == 'true' || raw == 't' || raw == '1' || raw == 'yes';
    } catch (e) {
      debugLog('⚠️ อ่าน shop_enabled ไม่สำเร็จ: $e');
      return false;
    }
  }

  /// เปิดให้ลูกค้าส่งคำขอเพิ่มร้านอยู่ไหม
  /// อ่านพลาด -> ถือว่าเปิด เพราะ server ปฏิเสธซ้ำให้อยู่แล้ว และการซ่อนปุ่มทิ้ง
  /// ทำให้ลูกค้าไม่มีทางบอกเราได้เลยว่าร้านที่ต้องการยังไม่มีในระบบ
  Future<bool> storeRequestEnabled() async {
    try {
      final row = await _client
          .from('system_config')
          .select('value')
          .eq('key', 'shop_store_request_enabled')
          .maybeSingle();
      final raw = (row?['value'] ?? '').toString().trim().toLowerCase();
      if (raw.isEmpty) return true;
      return raw == 'true' || raw == 't' || raw == '1' || raw == 'yes';
    } catch (e) {
      debugLog('⚠️ อ่าน shop_store_request_enabled ไม่สำเร็จ: $e');
      return true;
    }
  }

  /// ส่งคำขอเพิ่มตำแหน่งร้าน — ไม่ได้สร้างร้านทันที แอดมินต้องอนุมัติก่อน
  Future<Map<String, dynamic>> createStoreRequest({
    required String name,
    required String category,
    required double lat,
    required double lng,
    String? address,
    String? mapsUrl,
    bool is24h = false,
    String? note,
  }) =>
      _rpc('create_shop_store_request', {
        'p_name': name,
        'p_category': category,
        'p_lat': lat,
        'p_lng': lng,
        'p_address': address,
        'p_maps_url': mapsUrl,
        'p_is_24h': is24h,
        'p_note': note,
      });

  /// คำขอเพิ่มร้านของตัวเอง (RLS จำกัดให้เห็นเฉพาะของตัวเองอยู่แล้ว)
  Future<List<Map<String, dynamic>>> myStoreRequests() async {
    try {
      final rows = await _client
          .from('shop_store_requests')
          .select('id, name, status, admin_note, created_at')
          .order('created_at', ascending: false)
          .limit(20);
      return (rows as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (e) {
      debugLog('⚠️ อ่านคำขอเพิ่มร้านไม่สำเร็จ: $e');
      return const [];
    }
  }

  // ── ร้านค้า ────────────────────────────────────────────────────────────

  /// ร้านในรัศมี — server เรียงร้านที่เปิดอยู่ไว้ก่อนแล้ว
  Future<List<ShopStore>> nearbyStores({
    required double lat,
    required double lng,
    String? category,
  }) async {
    try {
      final res = await _client.rpc('shop_nearby_stores', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_category': category,
      });
      if (res is! List) return const [];
      return res
          .map((e) => ShopStore.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugLog('❌ shop_nearby_stores: $e');
      rethrow;
    }
  }

  /// สถานะร้านล่าสุด (ใช้เช็คซ้ำก่อนยืนยัน เผื่อร้านเพิ่งปิด)
  Future<Map<String, dynamic>?> storeStatus(String storeId) async {
    try {
      final res =
          await _client.rpc('shop_store_status', params: {'p_store_id': storeId});
      if (res is Map) return res.cast<String, dynamic>();
      return null;
    } catch (e) {
      debugLog('❌ shop_store_status: $e');
      return null;
    }
  }

  // ── ราคา ───────────────────────────────────────────────────────────────

  /// ขอราคาจาก server — ทุกบรรทัดใน dialog สรุปราคามาจากที่นี่
  Future<ShopQuote> quote({
    required String storeId,
    required double budgetCap,
    required double destLat,
    required double destLng,
    String vehicleType = 'motorcycle',
  }) async {
    final res = await _client.rpc('shop_quote', params: {
      'p_store_id': storeId,
      'p_budget_cap': budgetCap,
      'p_dest_lat': destLat,
      'p_dest_lng': destLng,
      'p_vehicle_type': vehicleType,
    });
    if (res is! Map) {
      return const ShopQuote(ok: false, error: 'unexpected_response');
    }
    return ShopQuote.fromJson(res.cast<String, dynamic>());
  }

  // ── สร้างออเดอร์ ────────────────────────────────────────────────────────

  /// สร้างออเดอร์ + กันวงเงินจาก Wallet (atomic ฝั่ง server)
  ///
  /// คืน map ดิบเพื่อให้หน้าจอจัดการ error code ได้ละเอียด
  /// (insufficient_balance / no_driver_available / store_closed / ...)
  Future<Map<String, dynamic>> createBooking({
    required String storeId,
    required double budgetCap,
    required double destLat,
    required double destLng,
    required String destAddress,
    required List<ShopDraftItem> items,
    String? note,
    String vehicleType = 'motorcycle',
  }) async {
    if (AuthService.userId == null) {
      return {'success': false, 'error': 'not_authenticated'};
    }

    final payload = items
        .where((i) => !i.isBlank)
        .map((i) => i.toRpcJson())
        .toList(growable: false);

    if (payload.isEmpty) {
      return {'success': false, 'error': 'items_required'};
    }

    try {
      final res = await _client.rpc('create_shop_booking', params: {
        'p_store_id': storeId,
        'p_budget_cap': budgetCap,
        'p_dest_lat': destLat,
        'p_dest_lng': destLng,
        'p_dest_address': destAddress,
        'p_items': payload,
        'p_note': (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        'p_vehicle_type': vehicleType,
      });
      if (res is Map) return res.cast<String, dynamic>();
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      debugLog('❌ create_shop_booking: $e');
      return {'success': false, 'error': 'rpc_failed', 'message': e.toString()};
    }
  }

  /// อัปโหลดรูปตัวอย่างของแต่ละรายการแล้วผูกกับออเดอร์
  ///
  /// ทำ **หลัง** สร้างออเดอร์สำเร็จเท่านั้น เพราะ policy ของ storage ตรวจสิทธิ์
  /// จาก booking_id ที่อยู่ใน path และเพราะรูปเป็นของไม่บังคับ — อัปโหลดล้ม
  /// ต้องไม่ทำให้ออเดอร์ที่กันเงินไปแล้วล้มตาม
  ///
  /// คืน true เมื่อผูกครบทุกรูปที่มี
  Future<bool> uploadItemImages({
    required String bookingId,
    required List<ShopDraftItem> items,
  }) async {
    final withPhoto = <int, String>{};
    var line = 0;
    for (final item in items) {
      if (item.isBlank) continue;
      line += 1; // line_no ต้องนับแบบเดียวกับ server (ข้ามบรรทัดว่าง)
      if (item.hasImage) withPhoto[line] = item.localImagePath!;
    }
    if (withPhoto.isEmpty) return true;

    final payload = <Map<String, dynamic>>[];
    for (final entry in withPhoto.entries) {
      final file = File(entry.value);
      if (!file.existsSync()) continue;
      final path = await StorageService.uploadPrivateFile(
        file: file,
        path: '$bookingId/ref',
        bucketName: receiptBucket,
        metadata: {'booking_id': bookingId},
      );
      if (path == null) {
        debugLog('⚠️ อัปโหลดรูปตัวอย่างบรรทัด ${entry.key} ไม่สำเร็จ');
        continue;
      }
      payload.add({'line_no': entry.key, 'path': path});
    }
    if (payload.isEmpty) return false;

    final res = await _rpc('shop_set_item_images', {
      'p_booking_id': bookingId,
      'p_images': payload,
    });
    return res['success'] == true && payload.length == withPhoto.length;
  }

  /// signed URL ของรูปตัวอย่าง 1 รูป
  Future<String?> signedRefImageUrl(String path) =>
      StorageService.signedUrl(bucketName: receiptBucket, path: path);

  // ── ติดตามออเดอร์ ───────────────────────────────────────────────────────

  Future<ShopOrder?> orderByBookingId(String bookingId) async {
    try {
      final orderRow = await _client
          .from('shop_orders')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();
      if (orderRow == null) return null;

      final itemRows = await _client
          .from('shop_order_items')
          .select()
          .eq('shop_order_id', orderRow['id'])
          .order('line_no');

      final items = (itemRows as List)
          .map((e) => ShopOrderItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      return ShopOrder.fromJson(orderRow.cast<String, dynamic>(), items: items);
    } catch (e) {
      debugLog('❌ โหลดออเดอร์ฝากซื้อไม่สำเร็จ: $e');
      return null;
    }
  }

  /// ลูกค้ายืนยันรูปสินค้า (ร้านที่ไม่ออกใบเสร็จ)
  Future<Map<String, dynamic>> confirmProof(String bookingId) async {
    try {
      final res = await _client
          .rpc('shop_customer_confirm_proof', params: {'p_booking_id': bookingId});
      if (res is Map) return res.cast<String, dynamic>();
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      debugLog('❌ shop_customer_confirm_proof: $e');
      return {'success': false, 'error': 'rpc_failed', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancel(String bookingId, {String? reason}) async {
    try {
      final res = await _client.rpc('cancel_shop_booking', params: {
        'p_booking_id': bookingId,
        'p_reason': reason,
      });
      if (res is Map) return res.cast<String, dynamic>();
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      debugLog('❌ cancel_shop_booking: $e');
      return {'success': false, 'error': 'rpc_failed', 'message': e.toString()};
    }
  }

  // ── ฝั่งคนขับ ───────────────────────────────────────────────────────────

  /// ชื่อ bucket ส่วนตัวสำหรับรูปใบเสร็จ/รูปสินค้า
  static const receiptBucket = 'shop-receipts';

  /// คนขับรับงาน — server ตรวจเพดานวงเงินของคนขับใหม่ให้เอง
  Future<Map<String, dynamic>> driverAccept(String bookingId) =>
      _rpc('shop_driver_accept', {'p_booking_id': bookingId});

  /// กดถึงร้าน — server ตรวจทั้งลำดับสถานะและตำแหน่งจริง
  ///
  /// [selfReported] = คนขับกดปุ่ม "ถึงร้านแล้วแต่ระบบไม่รับ" (เช่น GPS เพี้ยนในห้าง)
  /// ข้ามการตรวจตำแหน่งได้ แต่ server จะติดธงให้แอดมินตรวจ
  Future<Map<String, dynamic>> driverArrivedAtStore(
    String bookingId, {
    bool selfReported = false,
  }) =>
      _rpc('shop_driver_arrived_at_store', {
        'p_booking_id': bookingId,
        'p_self_reported': selfReported,
      });

  /// ติ๊กสถานะของแต่ละรายการ + กรอกราคาที่อ่านจากบิล
  ///
  /// [items] แต่ละตัว: {line_no, status, actual_price?, substitute_name?}
  Future<Map<String, dynamic>> driverUpdateItems(
    String bookingId,
    List<Map<String, dynamic>> items,
  ) =>
      _rpc('shop_driver_update_items', {
        'p_booking_id': bookingId,
        'p_items': items,
      });

  /// ยืนยันว่าซื้อครบแล้ว — ต้องมีหลักฐานอย่างน้อย 1 รูป
  Future<Map<String, dynamic>> markPurchased(
    String bookingId,
    List<String> proofPaths,
  ) =>
      _rpc('shop_mark_purchased', {
        'p_booking_id': bookingId,
        'p_proof_urls': proofPaths,
      });

  Future<Map<String, dynamic>> completeBooking(String bookingId) =>
      _rpc('complete_shop_booking', {'p_booking_id': bookingId});

  /// แปลง path ใน bucket ส่วนตัวเป็น signed URL สำหรับแสดงรูป
  Future<List<String>> signedProofUrls(List<String> paths) =>
      StorageService.signedUrls(bucketName: receiptBucket, paths: paths);

  Future<Map<String, dynamic>> _rpc(
    String fn,
    Map<String, dynamic> params,
  ) async {
    try {
      final res = await _client.rpc(fn, params: params);
      if (res is Map) return res.cast<String, dynamic>();
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      debugLog('❌ $fn: $e');
      return {'success': false, 'error': 'rpc_failed', 'message': e.toString()};
    }
  }

  // ── draft ในเครื่อง ─────────────────────────────────────────────────────
  //
  // จำเป็นเพราะตอนไปเติมเงินต้องออกจากแอปไปหน้า Beam จริง
  // ระบบปฏิบัติการอาจคืน memory ระหว่างนั้น ถ้าไม่เก็บลงที่เก็บถาวร
  // ลูกค้าจะกลับมาเจอรายการที่พิมพ์มาหายทั้งหมด

  Future<void> saveDraft({
    required String storeId,
    required String storeName,
    required List<ShopDraftItem> items,
    required double budgetCap,
    double? destLat,
    double? destLng,
    String? destAddress,
    String? note,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _draftKey,
        jsonEncode({
          'store_id': storeId,
          'store_name': storeName,
          'items': items.map((i) => i.toStorageJson()).toList(),
          'budget_cap': budgetCap,
          'dest_lat': destLat,
          'dest_lng': destLng,
          'dest_address': destAddress,
          'note': note,
          'saved_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      // draft หายไม่ควรทำให้สั่งของไม่ได้ — แค่ log
      debugLog('⚠️ เก็บ draft ฝากซื้อไม่สำเร็จ: $e');
    }
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();

      // draft เก่าเกิน 1 วันถือว่าไม่เกี่ยวแล้ว (ร้าน/ราคาเปลี่ยนไปแล้ว)
      final savedAt = DateTime.tryParse((map['saved_at'] ?? '').toString());
      if (savedAt == null ||
          DateTime.now().difference(savedAt) > const Duration(days: 1)) {
        await clearDraft();
        return null;
      }
      return map;
    } catch (e) {
      debugLog('⚠️ อ่าน draft ฝากซื้อไม่สำเร็จ: $e');
      return null;
    }
  }

  static List<ShopDraftItem> draftItemsFrom(Map<String, dynamic> draft) {
    final raw = draft['items'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => ShopDraftItem.fromStorageJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      debugLog('⚠️ ลบ draft ฝากซื้อไม่สำเร็จ: $e');
    }
  }
}

/// ขีดจำกัดที่แอดมินตั้งไว้ — ใช้กับ UI เท่านั้น server บังคับจริงอีกชั้น
class ShopLimits {
  final double minBudget;
  final double maxBudget;
  final int maxItems;
  final double budgetBufferPercent;

  const ShopLimits({
    this.minBudget = 100,
    this.maxBudget = 5000,
    this.maxItems = 30,
    this.budgetBufferPercent = 15,
  });
}
