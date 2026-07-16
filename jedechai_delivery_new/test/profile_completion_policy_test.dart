import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/profile_completion_policy.dart';

void main() {
  Map<String, dynamic> merchantProfile({
    Object? merchantServiceTypes = const ['food'],
    String? approvalStatus = 'approved',
    String? gpPlanId,
  }) {
    return {
      'role': 'merchant',
      'full_name': 'ร้านทดสอบ',
      'phone_number': '0812345678',
      'shop_address': '123 Test Road',
      if (merchantServiceTypes != null)
        'merchant_service_types': merchantServiceTypes,
      if (approvalStatus != null) 'approval_status': approvalStatus,
      if (gpPlanId != null) 'gp_plan_id': gpPlanId,
    };
  }

  test('merchant profile is incomplete when service type is missing or invalid',
      () {
    expect(
      isProfileCompleteForRole(merchantProfile(merchantServiceTypes: null)),
      isFalse,
    );
    expect(
      isProfileCompleteForRole(merchantProfile(merchantServiceTypes: const [])),
      isFalse,
    );
    expect(
      isProfileCompleteForRole(
        merchantProfile(merchantServiceTypes: const ['ride']),
      ),
      isFalse,
    );
    expect(
      isProfileCompleteForRole(
        merchantProfile(merchantServiceTypes: const ['food', 'laundry']),
      ),
      isFalse,
    );
  });

  test('merchant profile is complete with exactly one valid service type', () {
    expect(
      isProfileCompleteForRole(merchantProfile(merchantServiceTypes: const [
        'food',
      ])),
      isTrue,
    );
    expect(
      isProfileCompleteForRole(merchantProfile(merchantServiceTypes: const [
        'laundry',
      ])),
      isTrue,
    );
  });

  test('pending food merchant requires a GP plan before profile is complete',
      () {
    // ยังไม่อนุมัติ + ยังไม่เลือกแพลน -> ไม่ครบ
    expect(
      isProfileCompleteForRole(merchantProfile(approvalStatus: 'pending')),
      isFalse,
    );
    // ยังไม่อนุมัติ + เลือกแพลนแล้ว -> ครบ
    expect(
      isProfileCompleteForRole(
        merchantProfile(approvalStatus: 'pending', gpPlanId: 'plan-1'),
      ),
      isTrue,
    );
    // approval_status หาย (โปรไฟล์เก่า/ค่า default) ถือว่ายังไม่อนุมัติ
    expect(
      isProfileCompleteForRole(merchantProfile(approvalStatus: null)),
      isFalse,
    );
  });

  test('pending laundry merchant does not require a GP plan', () {
    expect(
      isProfileCompleteForRole(
        merchantProfile(
          approvalStatus: 'pending',
          merchantServiceTypes: const ['laundry'],
        ),
      ),
      isTrue,
    );
  });

  test('approved merchant without GP plan stays complete (legacy merchants)',
      () {
    expect(
      isProfileCompleteForRole(merchantProfile(approvalStatus: 'approved')),
      isTrue,
    );
  });

  test('driver profile does not require GP plan', () {
    expect(
      isProfileCompleteForRole({
        'role': 'driver',
        'full_name': 'คนขับทดสอบ',
        'phone_number': '0812345678',
        'license_plate': '1กก1234',
        'approval_status': 'pending',
      }),
      isTrue,
    );
  });
}
