/// Public invite URL encoded in the referral QR and share message.
class ReferralInviteLink {
  /// โดเมน production ปัจจุบันของ admin-web/หน้าเชิญ (ย้ายจาก jedechai-delivery.vercel.app
  /// เมื่อ 2026-09-26 — โดเมนเก่าตอบ DEPLOYMENT_NOT_FOUND แล้ว)
  // ไม่รับโดเมนเก่า: *.vercel.app ที่ปล่อยแล้วคนอื่นเอาไปใช้ได้ -> ปลอมลิงก์ใส่รหัสตัวเอง
  // (QR/ลิงก์เชิญเริ่มในแอป 1.24 ซึ่งยังไม่เคยปล่อยบนโดเมนเก่า จึงไม่มีลิงก์เก่าค้างอยู่)
  static const host = 'jdc-delivery.vercel.app';

  static final RegExp _codePattern = RegExp(r'^[A-Z0-9][A-Z0-9-]{0,31}$');

  static bool isValidCode(String code) =>
      _codePattern.hasMatch(code.trim().toUpperCase());

  static Uri build(String code) {
    final normalized = code.trim().toUpperCase();
    if (!isValidCode(normalized)) {
      throw ArgumentError.value(code, 'code', 'Invalid referral code');
    }
    return Uri.https(host, '/invite', {'code': normalized});
  }

  static String? codeFromUri(Uri uri) {
    final isWeb =
        uri.scheme == 'https' && uri.host == host && uri.path == '/invite';
    final isApp = uri.scheme == 'jdc' &&
        uri.host == 'invite' &&
        (uri.path.isEmpty || uri.path == '/');
    if (!isWeb && !isApp) return null;
    final codes = uri.queryParametersAll['code'];
    if (codes == null || codes.length != 1) return null;
    final code = codes.single.trim().toUpperCase();
    return isValidCode(code) ? code : null;
  }
}
