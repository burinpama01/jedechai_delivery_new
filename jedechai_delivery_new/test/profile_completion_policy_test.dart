import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/profile_completion_policy.dart';

void main() {
  Map<String, dynamic> merchantProfile({
    Object? merchantServiceTypes = const ['food'],
  }) {
    return {
      'role': 'merchant',
      'full_name': 'ร้านทดสอบ',
      'phone_number': '0812345678',
      'shop_address': '123 Test Road',
      if (merchantServiceTypes != null)
        'merchant_service_types': merchantServiceTypes,
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
}
