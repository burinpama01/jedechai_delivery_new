import 'dart:convert';

/// PromptPay QR Code Service
///
/// สร้าง PromptPay QR Code payload ตามมาตรฐาน EMVCo
/// รองรับ:
/// - เบอร์โทรศัพท์ (10 หลัก)
/// - เลขบัตรประชาชน (13 หลัก)
/// - National ID / Tax ID
/// - ระบุจำนวนเงิน หรือไม่ระบุ (ให้ผู้โอนกรอกเอง)
class PromptPayService {
  /// สร้าง PromptPay QR payload จากเบอร์โทร
  ///
  /// [phoneNumber] - เบอร์โทร 10 หลัก (เช่น 0812345678)
  /// [amount] - จำนวนเงิน (null = ไม่ระบุ)
  /// Returns: QR payload string สำหรับสร้าง QR Code
  static String generateFromPhone(String phoneNumber, {double? amount}) {
    // แปลงเบอร์โทรเป็นรูปแบบ 0066xxxxxxxxx (ตามมาตรฐาน BOT EMVCo)
    String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedPhone.startsWith('0') && !formattedPhone.startsWith('00')) {
      formattedPhone = '0066${formattedPhone.substring(1)}';
    } else if (formattedPhone.startsWith('66') && !formattedPhone.startsWith('0066')) {
      formattedPhone = '00$formattedPhone';
    }

    return _generatePayload(
      targetType: '01', // Phone number
      targetId: formattedPhone,
      amount: amount,
    );
  }

  /// สร้าง PromptPay QR payload จากเลขบัตรประชาชน
  ///
  /// [nationalId] - เลขบัตรประชาชน 13 หลัก
  /// [amount] - จำนวนเงิน (null = ไม่ระบุ)
  static String generateFromNationalId(String nationalId, {double? amount}) {
    final cleanId = nationalId.replaceAll(RegExp(r'[^0-9]'), '');
    return _generatePayload(
      targetType: '02', // National ID
      targetId: cleanId,
      amount: amount,
    );
  }

  /// สร้าง EMVCo QR payload
  static String _generatePayload({
    required String targetType,
    required String targetId,
    double? amount,
  }) {
    final data = StringBuffer();

    // Payload Format Indicator
    data.write(_tlv('00', '01'));

    // Point of Initiation Method
    // 11 = Static QR (ใช้ซ้ำได้), 12 = Dynamic QR (ใช้ครั้งเดียว)
    data.write(_tlv('01', amount != null ? '12' : '11'));

    // Merchant Account Information (PromptPay)
    final merchantInfo = StringBuffer();
    merchantInfo.write(_tlv('00', 'A000000677010111')); // PromptPay AID
    merchantInfo.write(_tlv(targetType, targetId));
    data.write(_tlv('29', merchantInfo.toString()));

    // Transaction Currency (THB = 764)
    data.write(_tlv('53', '764'));

    // Transaction Amount
    if (amount != null && amount > 0) {
      data.write(_tlv('54', amount.toStringAsFixed(2)));
    }

    // Country Code
    data.write(_tlv('58', 'TH'));

    // CRC placeholder (จะคำนวณทีหลัง)
    final dataWithoutCrc = data.toString();
    final crcInput = '${dataWithoutCrc}6304';
    final crc = _calculateCRC16(crcInput);

    return '${dataWithoutCrc}6304$crc';
  }

  /// สร้าง TLV (Tag-Length-Value) format
  static String _tlv(String tag, String value) {
    final length = value.length.toString().padLeft(2, '0');
    return '$tag$length$value';
  }

  /// คำนวณ CRC-16/CCITT-FALSE
  static String _calculateCRC16(String input) {
    final bytes = utf8.encode(input);
    int crc = 0xFFFF;

    for (final byte in bytes) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// แปลง QR payload เป็น URL สำหรับ QR Code API
  ///
  /// ใช้ QR Server API (ฟรี ไม่ต้อง key)
  static String getQrImageUrl(String payload, {int size = 300}) {
    final encoded = Uri.encodeComponent(payload);
    return 'https://api.qrserver.com/v1/create-qr-code/?size=${size}x$size&data=$encoded&format=png';
  }

  /// Validate เบอร์โทร
  static bool isValidPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return clean.length == 10 && clean.startsWith('0');
  }

  /// Validate เลขบัตรประชาชน
  static bool isValidNationalId(String id) {
    final clean = id.replaceAll(RegExp(r'[^0-9]'), '');
    return clean.length == 13;
  }
}
