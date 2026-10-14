import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/services/app_ad_service.dart';

void main() {
  group('isSafeAdUrl', () {
    test('รับเฉพาะ https ที่มี host', () {
      expect(isSafeAdUrl('https://line.me/R/ti/p/@jdc'), isTrue);
      expect(isSafeAdUrl('  https://example.com  '), isTrue);
      expect(isSafeAdUrl('http://example.com'), isFalse);
      expect(isSafeAdUrl('javascript:alert(1)'), isFalse);
      expect(isSafeAdUrl('intent://scan#Intent;end'), isFalse);
      expect(isSafeAdUrl('https://'), isFalse);
      expect(isSafeAdUrl(null), isFalse);
    });
  });

  group('shouldShowAdPopup', () {
    final now = DateTime(2026, 10, 14, 9, 0);

    test('ยังไม่เคยแสดง → แสดง', () {
      for (final f in ['once', 'daily', 'every_open']) {
        expect(
            shouldShowAdPopup(frequency: f, lastShownAt: null, now: now), isTrue,
            reason: f);
      }
    });

    test('once → ไม่แสดงซ้ำ', () {
      expect(
          shouldShowAdPopup(
              frequency: 'once',
              lastShownAt: now.subtract(const Duration(days: 30)),
              now: now),
          isFalse);
    });

    test('daily → วันเดียวกันไม่ซ้ำ, ข้ามวันแสดงใหม่', () {
      expect(
          shouldShowAdPopup(
              frequency: 'daily',
              lastShownAt: DateTime(2026, 10, 14, 0, 5),
              now: now),
          isFalse);
      expect(
          shouldShowAdPopup(
              frequency: 'daily',
              lastShownAt: DateTime(2026, 10, 13, 23, 59),
              now: now),
          isTrue);
    });

    test('every_open → แสดงทุกครั้ง, ค่าแปลก → ใช้ daily', () {
      expect(
          shouldShowAdPopup(
              frequency: 'every_open', lastShownAt: now, now: now),
          isTrue);
      expect(
          shouldShowAdPopup(frequency: 'weird', lastShownAt: now, now: now),
          isFalse);
    });
  });

  group('AppAd.fromMap', () {
    test('แถวก่อน migration: มีคูปอง = coupon', () {
      final ad = AppAd.fromMap({
        'id': 'a',
        'title': 'โปร',
        'image_url': 'https://x/a.png',
        'page': 'home',
        'coupon_code': 'SAVE10',
      });
      expect(ad.action, AppAdAction.coupon);
      expect(ad.isTappable, isTrue);
    });

    test('url ที่ไม่ใช่ https กดไม่ได้', () {
      final ad = AppAd.fromMap({
        'id': 'b',
        'image_url': 'https://x/b.png',
        'page': 'driver_home',
        'action_type': 'url',
        'action_value': 'http://example.com',
      });
      expect(ad.action, AppAdAction.url);
      expect(ad.isTappable, isFalse);
    });

    test('none กดไม่ได้, popup_frequency default daily', () {
      final ad = AppAd.fromMap({
        'id': 'c',
        'image_url': 'https://x/c.png',
        'page': 'merchant_popup',
        'action_type': 'none',
      });
      expect(ad.isTappable, isFalse);
      expect(ad.popupFrequency, 'daily');
    });
  });
}
