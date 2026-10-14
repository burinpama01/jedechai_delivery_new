import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// โฆษณาในแอพ (ตาราง `banners`) — ลูกค้า / คนขับ / ร้านค้า
///
/// แอดมินจัดการที่ admin-web → ตั้งค่า → จัดการ Banner
/// ช่วงเวลาแสดง (starts_at/ends_at) + is_active ตัดที่ RLS ฝั่ง server แล้ว
/// แผน: Plan/In_App_Ads_Plan_v1.html
class AppAdPlacement {
  AppAdPlacement._();

  // ค่าในคอลัมน์ banners.page — ต้องตรงกับ supabase/functions/_shared/banner-ads.ts
  static const customerHome = 'home';
  static const customerFood = 'food';
  static const customerPopup = 'customer_popup';
  static const customerCardActivity = 'customer_card_activity';
  static const customerCardWallet = 'customer_card_wallet';
  static const driverHome = 'driver_home';
  static const driverPopup = 'driver_popup';
  static const driverCardWallet = 'driver_card_wallet';
  static const merchantHome = 'merchant_home';
  static const merchantPopup = 'merchant_popup';
  static const merchantCardOrders = 'merchant_card_orders';
}

enum AppAdAction { none, coupon, url, screen }

class AppAd {
  const AppAd({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.page,
    required this.action,
    this.actionValue,
    this.couponCode,
    this.popupFrequency = 'daily',
  });

  final String id;
  final String title;
  final String imageUrl;
  final String page;
  final AppAdAction action;
  final String? actionValue;
  final String? couponCode;
  final String popupFrequency;

  factory AppAd.fromMap(Map<String, dynamic> m) {
    final coupon = (m['coupon_code'] as String?)?.trim();
    final rawAction = m['action_type'] as String?;
    final action = switch (rawAction) {
      'coupon' => AppAdAction.coupon,
      'url' => AppAdAction.url,
      'screen' => AppAdAction.screen,
      'none' => AppAdAction.none,
      // แถวก่อน migration: มีคูปอง = coupon
      _ => (coupon != null && coupon.isNotEmpty)
          ? AppAdAction.coupon
          : AppAdAction.none,
    };
    return AppAd(
      id: '${m['id']}',
      title: (m['title'] as String?) ?? '',
      imageUrl: (m['image_url'] as String?) ?? '',
      page: (m['page'] as String?) ?? AppAdPlacement.customerHome,
      action: action,
      actionValue: m['action_value'] as String?,
      couponCode: coupon,
      popupFrequency: (m['popup_frequency'] as String?) ?? 'daily',
    );
  }

  /// การกดทำอะไรได้จริงไหม (ข้อมูลครบ)
  bool get isTappable => switch (action) {
        AppAdAction.coupon => (couponCode ?? '').isNotEmpty,
        AppAdAction.url => isSafeAdUrl(actionValue),
        AppAdAction.screen => (actionValue ?? '').isNotEmpty,
        AppAdAction.none => false,
      };
}

/// รับเฉพาะ https:// (กัน javascript:, intent:, http)
bool isSafeAdUrl(String? url) {
  if (url == null) return false;
  final uri = Uri.tryParse(url.trim());
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

/// ตัดสินว่าป๊อปอัปควรแสดงไหม จากความถี่และเวลาที่แสดงครั้งล่าสุด (pure — ทดสอบได้)
bool shouldShowAdPopup({
  required String frequency,
  required DateTime? lastShownAt,
  required DateTime now,
}) {
  if (lastShownAt == null) return true;
  switch (frequency) {
    case 'every_open':
      return true;
    case 'once':
      return false;
    case 'daily':
    default:
      final last = lastShownAt.toLocal();
      final today = now.toLocal();
      return last.year != today.year ||
          last.month != today.month ||
          last.day != today.day;
  }
}

/// คัดป๊อปอัปที่ถึงรอบแสดง (คงลำดับเดิม) — pure, ทดสอบได้
List<AppAd> pickDuePopups(
  List<AppAd> ads, {
  required DateTime? Function(String adId) lastShownAt,
  required DateTime now,
}) =>
    ads
        .where((ad) => shouldShowAdPopup(
            frequency: ad.popupFrequency,
            lastShownAt: lastShownAt(ad.id),
            now: now))
        .toList();

class AppAdService {
  AppAdService._();

  static const _cacheTtl = Duration(minutes: 2);
  static final Map<String, ({DateTime at, List<AppAd> ads})> _cache = {};

  /// โฆษณาที่กำลังแสดงของตำแหน่งนั้น (เรียงตาม sort_order)
  /// error → คืนลิสต์ว่าง ไม่ให้หน้าจอพัง
  static Future<List<AppAd>> fetch(String placement,
      {bool forceRefresh = false}) async {
    final cached = _cache[placement];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.ads;
    }
    try {
      final rows = await SupabaseService.client
          .from('banners')
          .select(
              'id,title,image_url,page,sort_order,action_type,action_value,coupon_code,popup_frequency')
          .eq('is_active', true)
          .eq('page', placement)
          .order('sort_order')
          .order('created_at', ascending: false);
      final ads = List<Map<String, dynamic>>.from(rows)
          .map(AppAd.fromMap)
          .where((a) => a.imageUrl.isNotEmpty)
          .toList();
      _cache[placement] = (at: DateTime.now(), ads: ads);
      return ads;
    } catch (e) {
      debugLog('⚠️ Error loading ads ($placement): $e');
      return cached?.ads ?? const [];
    }
  }

  /// ล้าง cache (ใช้ตอนดึงลงรีเฟรช)
  static void invalidate([String? placement]) {
    if (placement == null) {
      _cache.clear();
    } else {
      _cache.remove(placement);
    }
  }

  static String _prefKey(String adId) => 'app_ad_popup_shown_$adId';

  /// ป๊อปอัปทุกตัวที่ถึงรอบแสดง เรียงตาม sort_order (ว่าง = ไม่ต้องแสดง)
  static Future<List<AppAd>> duePopups(String placement) async {
    // ไม่ใช้ cache — เรียกครั้งเดียวตอนเปิดแอพ ต้องได้ชุดล่าสุดที่แอดมินเพิ่งตั้ง
    final ads = await fetch(placement, forceRefresh: true);
    if (ads.isEmpty) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      return pickDuePopups(
        ads,
        lastShownAt: (id) {
          final ms = prefs.getInt(_prefKey(id));
          return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
        },
        now: DateTime.now(),
      );
    } catch (e) {
      debugLog('⚠️ Error reading ad popup state: $e');
      return const [];
    }
  }

  static Future<void> markPopupShown(String adId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _prefKey(adId), DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugLog('⚠️ Error saving ad popup state: $e');
    }
  }
}
