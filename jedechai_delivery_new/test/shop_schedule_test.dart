import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/shop_schedule.dart';

/// helper: สร้างเวลา UTC จาก wall clock กรุงเทพ (UTC+7)
DateTime bangkokUtc(int y, int m, int d, int hh, int mm) =>
    DateTime.utc(y, m, d, hh, mm).subtract(const Duration(hours: 7));

void main() {
  group('isShopOpenNow — manual status', () {
    test('ใช้ shop_status ตรง ๆ เมื่อไม่ได้เปิด auto schedule', () {
      expect(isShopOpenNow({'shop_status': true}), isTrue);
      expect(isShopOpenNow({'shop_status': false}), isFalse);
      expect(isShopOpenNow({'shop_status': 1}), isTrue);
      expect(isShopOpenNow({'shop_status': 'true'}), isTrue);
    });

    test('ตกกลับไปใช้ shop_status เมื่อเวลาเปิด/ปิดไม่ครบหรือ parse ไม่ได้', () {
      expect(
        isShopOpenNow({
          'shop_auto_schedule_enabled': true,
          'shop_status': true,
          'shop_open_time': '09:00',
        }),
        isTrue,
      );
      expect(
        isShopOpenNow({
          'shop_auto_schedule_enabled': true,
          'shop_status': true,
          'shop_open_time': 'abc',
          'shop_close_time': '18:00',
        }),
        isTrue,
      );
    });
  });

  group('isShopOpenNow — กะปกติ (ไม่ข้ามเที่ยงคืน)', () {
    final shop = {
      'shop_auto_schedule_enabled': true,
      'shop_status': false,
      'shop_open_time': '09:00',
      'shop_close_time': '18:00',
    };

    test('เปิดระหว่างช่วงเวลาทำการ', () {
      expect(
        isShopOpenNow(shop, nowUtc: bangkokUtc(2026, 9, 18, 12, 0)),
        isTrue,
      );
    });

    test('ปิดก่อนเวลาเปิดและตั้งแต่เวลาปิด', () {
      expect(
        isShopOpenNow(shop, nowUtc: bangkokUtc(2026, 9, 18, 8, 59)),
        isFalse,
      );
      expect(
        isShopOpenNow(shop, nowUtc: bangkokUtc(2026, 9, 18, 18, 0)),
        isFalse,
      );
    });
  });

  group('isShopOpenNow — กะข้ามเที่ยงคืน (ISSUE-112)', () {
    // ร้านเปิดเฉพาะคืนวันศุกร์ 18:00 ถึงตี 2 ของเช้าวันเสาร์
    final nightShop = {
      'shop_auto_schedule_enabled': true,
      'shop_status': false,
      'shop_open_time': '18:00',
      'shop_close_time': '02:00',
      'shop_open_days': ['fri'],
    };

    // 2026-09-18 เป็นวันศุกร์, 2026-09-19 เป็นวันเสาร์
    test('เปิดตอนสี่ทุ่มของวันศุกร์', () {
      expect(
        isShopOpenNow(nightShop, nowUtc: bangkokUtc(2026, 9, 18, 22, 0)),
        isTrue,
      );
    });

    test('ยังเปิดตอนตีหนึ่งของเช้าวันเสาร์ เพราะยังเป็นกะของวันศุกร์', () {
      expect(
        isShopOpenNow(nightShop, nowUtc: bangkokUtc(2026, 9, 19, 1, 0)),
        isTrue,
      );
    });

    test('ปิดตอนตีสามของวันเสาร์ เพราะเลยเวลาปิดแล้ว', () {
      expect(
        isShopOpenNow(nightShop, nowUtc: bangkokUtc(2026, 9, 19, 3, 0)),
        isFalse,
      );
    });

    test('ปิดตอนสี่ทุ่มของวันเสาร์ เพราะเสาร์ไม่ใช่วันเปิดร้าน', () {
      expect(
        isShopOpenNow(nightShop, nowUtc: bangkokUtc(2026, 9, 19, 22, 0)),
        isFalse,
      );
    });

    test('ปิดตอนตีหนึ่งของเช้าวันศุกร์ เพราะกะนั้นเป็นของวันพฤหัส', () {
      expect(
        isShopOpenNow(nightShop, nowUtc: bangkokUtc(2026, 9, 18, 1, 0)),
        isFalse,
      );
    });
  });
}
