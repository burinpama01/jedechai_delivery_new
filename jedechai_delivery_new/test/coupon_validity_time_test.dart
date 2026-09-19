import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/coupon.dart';

Map<String, dynamic> couponJson({String? endDate, String? startDate}) => {
      'id': 'c1',
      'code': 'TEST10',
      'name': 'ทดสอบ',
      'discount_type': 'fixed',
      'discount_value': 10,
      'created_at': '2026-01-01T00:00:00',
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    };

void main() {
  group('Coupon.fromJson — การแปลงเวลา (ISSUE-113)', () {
    test('timestamp ที่ไม่มี offset ถูกอ่านเป็น UTC ไม่ใช่เวลาเครื่อง', () {
      final coupon = Coupon.fromJson(couponJson(endDate: '2026-12-31T23:59:59'));

      expect(coupon.endDate!.isUtc, isTrue);
      expect(coupon.endDate, DateTime.utc(2026, 12, 31, 23, 59, 59));
    });

    test('timestamp ที่มี offset ถูกแปลงกลับเป็น UTC ตาม offset นั้น', () {
      final coupon =
          Coupon.fromJson(couponJson(endDate: '2026-12-31T23:59:59+07:00'));

      expect(coupon.endDate!.isUtc, isTrue);
      expect(coupon.endDate, DateTime.utc(2026, 12, 31, 16, 59, 59));
    });

    test('createdAt ก็ถูกอ่านเป็น UTC เหมือนกัน', () {
      final coupon = Coupon.fromJson(couponJson());

      expect(coupon.createdAt.isUtc, isTrue);
      expect(coupon.createdAt, DateTime.utc(2026, 1, 1));
    });
  });

  group('Coupon.isExpired / isValid — เทียบ instant จริง', () {
    Coupon build({DateTime? start, DateTime? end}) => Coupon(
          id: 'c1',
          code: 'TEST10',
          name: 'ทดสอบ',
          discountType: 'fixed',
          discountValue: 10,
          startDate: start,
          endDate: end,
          createdAt: DateTime.utc(2026, 1, 1),
        );

    test('คูปองที่ยังไม่ถึงกำหนดหมดอายุ ต้องไม่ถูกตัดสินว่าหมดอายุ', () {
      final end = DateTime.now().toUtc().add(const Duration(hours: 3));

      expect(build(end: end).isExpired, isFalse);
      expect(build(end: end).isValid, isTrue);
    });

    test('ช่องว่างน้อยกว่า 7 ชั่วโมงก็ยังต้องไม่หมดอายุ (กันการบวก offset ซ้ำ)',
        () {
      final end = DateTime.now().toUtc().add(const Duration(hours: 1));

      expect(build(end: end).isExpired, isFalse);
    });

    test('คูปองที่เลยกำหนดแล้วต้องหมดอายุ', () {
      final end = DateTime.now().toUtc().subtract(const Duration(minutes: 1));

      expect(build(end: end).isExpired, isTrue);
      expect(build(end: end).isValid, isFalse);
    });

    test('คูปองที่ยังไม่เริ่มต้องยังใช้ไม่ได้', () {
      final start = DateTime.now().toUtc().add(const Duration(hours: 1));

      expect(build(start: start).isValid, isFalse);
    });
  });
}
