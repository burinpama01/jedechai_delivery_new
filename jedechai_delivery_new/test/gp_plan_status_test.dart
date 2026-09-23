import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_gp_plan_screen.dart';
import 'package:jedechai_delivery_new/common/services/gp_plan_service.dart';

void main() {
  group('GpPlanStatus', () {
    test('parses cooldown and compensates device clock skew', () {
      // เครื่องช้ากว่า server 1 ชั่วโมง
      final localNow = DateTime.utc(2026, 9, 19, 14);
      final status = GpPlanStatus.fromJson({
        'plan_id': 'a1000000-0000-4000-8000-000000000002',
        'approval_status': 'approved',
        'is_custom_deal': false,
        'can_change': false,
        'blocked_reason': 'cooldown',
        'next_change_at': '2026-10-19T15:00:00+00:00',
        'server_now': '2026-09-19T15:00:00+00:00',
        'cooldown_days': 30,
        'gp_rate': 0.2,
        'custom_base_fare': 5,
        'custom_base_distance': 7,
        'custom_per_km': 2,
      }, now: localNow);

      expect(status.isApproved, isTrue);
      expect(status.canChange, isFalse);
      expect(status.blockedReason, 'cooldown');
      expect(status.gpRate, 0.2);
      expect(status.remainingCooldown(now: localNow), const Duration(days: 30));
    });

    test('remaining is null without cooldown and zero once expired', () {
      final none = GpPlanStatus.fromJson({
        'approval_status': 'approved',
        'can_change': true,
        'next_change_at': null,
      });
      expect(none.remainingCooldown(), isNull);

      final now = DateTime.utc(2026, 9, 19);
      final expired = GpPlanStatus.fromJson({
        'next_change_at': '2026-09-18T00:00:00Z',
        'server_now': '2026-09-19T00:00:00Z',
      }, now: now);
      expect(expired.remainingCooldown(now: now), Duration.zero);
    });

    test('custom deal flag', () {
      final s = GpPlanStatus.fromJson({
        'approval_status': 'approved',
        'is_custom_deal': true,
        'can_change': false,
        'blocked_reason': 'custom_deal',
      });
      expect(s.isCustomDeal, isTrue);
      expect(s.planId, isNull);
    });
  });

  group('formatGpCooldown', () {
    test('with days', () {
      expect(
        formatGpCooldown(const Duration(days: 12, hours: 3, minutes: 21, seconds: 9)),
        '12 วัน 03:21:09',
      );
    });
    test('under a day', () {
      expect(formatGpCooldown(const Duration(minutes: 5, seconds: 2)), '00:05:02');
    });
  });

  group('GpPlanService.errorMessage', () {
    test('maps server error codes to Thai messages', () {
      expect(GpPlanService.errorMessage(Exception('gp_plan_cooldown')),
          contains('เดือนละ 1 ครั้ง'));
      expect(GpPlanService.errorMessage(Exception('custom_deal_contact_admin')),
          contains('ติดต่อแอดมิน'));
      expect(GpPlanService.errorMessage(Exception('active_orders_exist')),
          contains('ออเดอร์'));
    });
  });
}
