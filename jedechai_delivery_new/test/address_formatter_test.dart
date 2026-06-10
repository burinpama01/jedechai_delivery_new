import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/address_formatter.dart';

void main() {
  group('formatAddressValue', () {
    test('formats JSON string with all address components', () {
      final formatted = formatAddressValue(
        '{"address":"12/3 หมู่ 4","subLocality":"เจดีย์ชัย","locality":"ปัว","administrativeArea":"น่าน","country":"ไทย"}',
        unknownLabel: 'ไม่ทราบที่อยู่',
        currentLocationLabel: 'ตำแหน่งปัจจุบัน',
      );

      expect(formatted, '12/3 หมู่ 4, เจดีย์ชัย, ปัว, น่าน, ไทย');
    });

    test('formats map and JSON string consistently', () {
      final addressMap = {
        'address': '12/3 หมู่ 4',
        'subLocality': 'เจดีย์ชัย',
        'locality': 'ปัว',
        'administrativeArea': 'น่าน',
        'country': 'ไทย',
      };
      const jsonAddress =
          '{"address":"12/3 หมู่ 4","subLocality":"เจดีย์ชัย","locality":"ปัว","administrativeArea":"น่าน","country":"ไทย"}';

      final mapFormatted = formatAddressValue(
        addressMap,
        unknownLabel: 'ไม่ทราบที่อยู่',
        currentLocationLabel: 'ตำแหน่งปัจจุบัน',
      );
      final jsonFormatted = formatAddressValue(
        jsonAddress,
        unknownLabel: 'ไม่ทราบที่อยู่',
        currentLocationLabel: 'ตำแหน่งปัจจุบัน',
      );

      expect(jsonFormatted, mapFormatted);
    });
  });
}
