import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/shop_order.dart';
import 'package:jedechai_delivery_new/common/models/shop_quote.dart';
import 'package:jedechai_delivery_new/common/models/shop_store.dart';

void main() {
  group('ShopQuote', () {
    test('อ่านราคาจาก server ครบทุกบรรทัด', () {
      final q = ShopQuote.fromJson({
        'ok': true,
        'budget_cap': 500.00,
        'distance_km': 4.2,
        'delivery_fee': 35.00,
        'service_fee': 50.00,
        'far_pickup_fee': 20.00,
        'total_fees': 105.00,
        'hold_amount': 605.00,
        'wallet_balance': 1240.00,
        'sufficient': true,
        'shortfall': 0,
        'cancel_fee_if_shopping': 100.00,
        'quoted_at': '2026-09-23T10:00:00+07:00',
        'quote_ttl_sec': 120,
        'driver': {
          'has_driver': true,
          'nearest_km': 24.0,
          'driver_count_in_radius': 3,
          'is_outside_radius': true,
        },
      });

      expect(q.ok, isTrue);
      expect(q.holdAmount, 605.00);
      expect(q.farPickupFee, 20.00);
      expect(q.cancelFeeIfShopping, 100.00);
      expect(q.sufficient, isTrue);
      expect(q.hasDriver, isTrue);
      expect(q.driverCountInRadius, 3);
      expect(q.driverOutsideRadius, isTrue);
      expect(q.nearestDriverKm, 24.0);
    });

    test('เงินไม่พอ -> sufficient false และรู้ยอดที่ขาด', () {
      final q = ShopQuote.fromJson({
        'ok': true,
        'hold_amount': 605.00,
        'wallet_balance': 200.00,
        'sufficient': false,
        'shortfall': 405.00,
        'driver': {'has_driver': true},
      });
      expect(q.sufficient, isFalse);
      expect(q.shortfall, 405.00);
    });

    test('server ปฏิเสธ -> เก็บ error code ไว้ให้ UI แปลข้อความ', () {
      final closed = ShopQuote.fromJson({
        'ok': false,
        'error': 'store_closed',
        'next_open_at': '2026-09-24T08:00:00+07:00',
      });
      expect(closed.ok, isFalse);
      expect(closed.error, 'store_closed');
      expect(closed.nextOpenAt, isNotNull);

      final noDriver =
          ShopQuote.fromJson({'ok': false, 'error': 'no_driver_available'});
      expect(noDriver.error, 'no_driver_available');
      // ไม่มีคนขับต้องไม่หลุดเป็น hasDriver = true
      expect(noDriver.hasDriver, isFalse);
    });

    test('ราคาหมดอายุตาม ttl', () {
      final fresh = ShopQuote(
        ok: true,
        quotedAt: DateTime.now(),
        quoteTtlSec: 120,
      );
      expect(fresh.isExpired, isFalse);

      final old = ShopQuote(
        ok: true,
        quotedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        quoteTtlSec: 120,
      );
      expect(old.isExpired, isTrue);
    });
  });

  group('ShopStore', () {
    test('อ่านสถานะเปิด/ปิดที่ server คำนวณมา', () {
      final open = ShopStore.fromJson({
        'id': 's1',
        'name': 'ร้านชำ',
        'category': 'grocery',
        'lat': 13.7563,
        'lng': 100.5018,
        'distance_km': 1.2,
        'is_open_now': true,
        'next_open_at': null,
        'issues_receipt': true,
      });
      expect(open.isOpenNow, isTrue);
      expect(open.nextOpenAt, isNull);
      expect(open.issuesReceipt, isTrue);

      final closed = ShopStore.fromJson({
        'id': 's2',
        'name': 'ตลาดสด',
        'category': 'market',
        'lat': 13.76,
        'lng': 100.51,
        'distance_km': 2.0,
        'is_open_now': false,
        'next_open_at': '2026-09-24T06:00:00+07:00',
        'issues_receipt': false,
      });
      expect(closed.isOpenNow, isFalse);
      expect(closed.nextOpenAt, isNotNull);
      // ร้านไม่ออกใบเสร็จต้องถูกตีความถูก ไม่งั้น flow หลักฐานจะผิด
      expect(closed.issuesReceipt, isFalse);
    });

    test('ค่าที่ขาดหายไม่ทำให้พัง', () {
      final s = ShopStore.fromJson({'id': 'x', 'lat': 1, 'lng': 1});
      expect(s.name, '');
      expect(s.category, 'grocery');
      expect(s.distanceKm, 0);
      expect(s.isOpenNow, isFalse);
    });
  });

  group('ShopOrder', () {
    ShopOrderItem item(int line, String status, {double? price}) =>
        ShopOrderItem.fromJson({
          'id': 'i$line',
          'line_no': line,
          'name_text': 'ของ $line',
          'status': status,
          'actual_price': price,
        });

    test('รวมยอดเฉพาะของที่ซื้อได้ และนับของหมดถูก', () {
      final order = ShopOrder.fromJson(
        {
          'id': 'o1',
          'booking_id': 'b1',
          'store_id': 's1',
          'store_name': 'ร้าน',
          'store_category': 'grocery',
          'store_lat': 13.0,
          'store_lng': 100.0,
          'proof_mode': 'receipt',
          'budget_cap': 500,
          'hold_amount': 575,
          'service_fee': 50,
          'delivery_fee': 25,
          'far_pickup_fee': 0,
          'proof_urls': <String>[],
        },
        items: [
          item(1, 'bought', price: 58),
          item(2, 'substituted', price: 135),
          item(3, 'unavailable'),
          item(4, 'pending'),
        ],
      );

      expect(order.boughtSubtotal, 193);
      expect(order.unavailableCount, 1);
      // ร้านออกใบเสร็จ -> ไม่ต้องให้ลูกค้ายืนยันรูป
      expect(order.needsCustomerConfirm, isFalse);
    });

    test('ค่าปรับยกเลิกอ่านจาก snapshot ของ server ไม่ใช่สูตรที่ hardcode ในแอป', () {
      Map<String, dynamic> base(Map<String, dynamic>? snap) => {
            'id': 'o3',
            'booking_id': 'b3',
            'store_id': 's3',
            'store_name': 'ร้าน',
            'store_category': 'grocery',
            'store_lat': 13.0,
            'store_lng': 100.0,
            'proof_mode': 'receipt',
            'budget_cap': 500,
            'hold_amount': 605,
            'service_fee': 80,
            'delivery_fee': 25,
            'far_pickup_fee': 0,
            'proof_urls': <String>[],
            'fee_config_snapshot': snap,
          };

      // 25% ของ 605 = 151.25 -> ชนเพดาน 100
      final capped = ShopOrder.fromJson(
          base({'cancel_fee_pct': 25, 'cancel_fee_max': 100}));
      expect(capped.cancelFeeIfShopping, 100);

      // ถ้าแอดมินตั้งเพดานไว้สูงกว่า ต้องคิดตาม % จริง ไม่ใช่ค้างที่ 100
      final byPercent = ShopOrder.fromJson(
          base({'cancel_fee_pct': 25, 'cancel_fee_max': 500}));
      expect(byPercent.cancelFeeIfShopping, 151.25);

      // อัตราอื่นที่ไม่ใช่ 25% ก็ต้องตามนั้น (พิสูจน์ว่าไม่ได้ hardcode)
      final tenPercent = ShopOrder.fromJson(
          base({'cancel_fee_pct': 10, 'cancel_fee_max': 500}));
      expect(tenPercent.cancelFeeIfShopping, 60.5);

      // อ่าน snapshot ไม่ได้ -> ต้องคืน null เพื่อไม่ให้ UI แสดงเลขมั่ว
      expect(ShopOrder.fromJson(base(null)).cancelFeeIfShopping, isNull);
      expect(ShopOrder.fromJson(base({})).cancelFeeIfShopping, isNull);
    });

    test('ร้านไม่ออกใบเสร็จต้องรอลูกค้ายืนยันจนกว่าจะยืนยันจริง', () {
      Map<String, dynamic> base(String? confirmedAt) => {
            'id': 'o2',
            'booking_id': 'b2',
            'store_id': 's2',
            'store_name': 'ตลาด',
            'store_category': 'market',
            'store_lat': 13.0,
            'store_lng': 100.0,
            'proof_mode': 'photo',
            'budget_cap': 300,
            'hold_amount': 355,
            'service_fee': 30,
            'delivery_fee': 25,
            'far_pickup_fee': 0,
            'proof_urls': ['https://x/a.jpg'],
            'customer_confirmed_at': confirmedAt,
          };

      expect(ShopOrder.fromJson(base(null)).needsCustomerConfirm, isTrue);
      expect(
        ShopOrder.fromJson(base('2026-09-23T10:00:00+07:00'))
            .needsCustomerConfirm,
        isFalse,
      );
    });

    test('คำขอเพิ่มวงเงิน: แสดงเฉพาะที่รอตอบและมียอดจริง', () {
      Map<String, dynamic> base(String? status, Object? amount) => {
            'id': 'o3',
            'booking_id': 'b3',
            'store_id': 's3',
            'store_name': 'ร้าน',
            'budget_cap': 300,
            'hold_amount': 380,
            'budget_increase_status': status,
            'budget_increase_amount': amount,
          };

      final requested = ShopOrder.fromJson(base('requested', '107.00'));
      expect(requested.hasPendingBudgetIncrease, isTrue);
      expect(requested.budgetIncreaseAmount, 107);

      expect(ShopOrder.fromJson(base('approved', 107)).hasPendingBudgetIncrease,
          isFalse);
      expect(ShopOrder.fromJson(base('declined', 107)).hasPendingBudgetIncrease,
          isFalse);
      expect(ShopOrder.fromJson(base('requested', 0)).hasPendingBudgetIncrease,
          isFalse);
      expect(ShopOrder.fromJson(base(null, null)).hasPendingBudgetIncrease,
          isFalse);
    });
  });

  group('ShopDraftItem', () {
    test('แถวว่างถูกมองว่า blank และไม่ถูกส่งขึ้น server', () {
      expect(ShopDraftItem().isBlank, isTrue);
      expect(ShopDraftItem(name: '   ').isBlank, isTrue);
      expect(ShopDraftItem(name: 'นม').isBlank, isFalse);
    });

    test('ตัดช่องว่างก่อนส่ง RPC', () {
      final i = ShopDraftItem(name: '  นม  ', quantity: ' 2 กล่อง ', note: ' ');
      final json = i.toRpcJson();
      expect(json['name'], 'นม');
      expect(json['quantity'], '2 กล่อง');
      expect(json['note'], '');
    });

    test('เก็บลง draft แล้วอ่านกลับได้เหมือนเดิม (กันรายการหายตอนไปเติมเงิน)', () {
      final original =
          ShopDraftItem(name: 'ไข่ไก่', quantity: '1 แผง', note: 'เบอร์ 2');
      final restored =
          ShopDraftItem.fromStorageJson(original.toStorageJson());
      expect(restored.name, original.name);
      expect(restored.quantity, original.quantity);
      expect(restored.note, original.note);
    });

    test('รูปตัวอย่างในเครื่องติดไปกับ draft แต่ไม่ถูกส่งขึ้น RPC', () {
      final original = ShopDraftItem(name: 'นม', localImagePath: '/tmp/a.jpg');
      expect(original.hasImage, isTrue);
      expect(original.toRpcJson().containsKey('local_image_path'), isFalse);
      final restored =
          ShopDraftItem.fromStorageJson(original.toStorageJson());
      expect(restored.localImagePath, '/tmp/a.jpg');
      expect(ShopDraftItem(name: 'นม', localImagePath: ' ').hasImage, isFalse);
      // draft รุ่นเก่าที่ไม่มี key รูป ต้องอ่านได้
      expect(ShopDraftItem.fromStorageJson({'name': 'x'}).hasImage, isFalse);
    });
  });

  group('ShopOrderItem.refImagePath', () {
    Map<String, dynamic> row(Object? path) => {
          'id': 'i1',
          'line_no': 1,
          'name': 'นม',
          'status': 'pending',
          'ref_image_path': path,
        };

    test('อ่าน path รูปตัวอย่าง และค่าว่างเป็น null', () {
      expect(ShopOrderItem.fromJson(row('b/ref/1.jpg')).refImagePath,
          'b/ref/1.jpg');
      expect(ShopOrderItem.fromJson(row('')).refImagePath, isNull);
      expect(ShopOrderItem.fromJson(row(null)).refImagePath, isNull);
    });
  });
}
