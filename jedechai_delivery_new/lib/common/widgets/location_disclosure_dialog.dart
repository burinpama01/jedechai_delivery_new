import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prominent Disclosure Dialog สำหรับ Google Play Policy
///
/// แสดงคำประกาศเตือนเรื่องการเก็บข้อมูลตำแหน่งที่ตั้ง
/// ก่อนที่จะเด้ง System Permission Dialog ของ Android
///
/// ต้องแสดงก่อนการขอ permission ทุกครั้ง (ครั้งแรก)
class LocationDisclosureHelper {
  static const _prefKey = 'location_disclosure_accepted';

  /// ตรวจสอบว่าผู้ใช้ยอมรับ disclosure แล้วหรือยัง
  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// แสดง Prominent Disclosure Dialog
  /// Returns true ถ้าผู้ใช้กด "ยอมรับ", false ถ้ากด "ไม่ยอมรับ"
  /// ถ้าเคยยอมรับแล้ว จะ return true ทันทีโดยไม่แสดง dialog
  static Future<bool> showIfNeeded(BuildContext context) async {
    if (await hasAccepted()) return true;
    if (!context.mounted) return false;
    return await _showDisclosureDialog(context);
  }

  /// บังคับแสดง disclosure ทุกครั้ง (ไม่สนว่าเคยยอมรับแล้ว)
  static Future<bool> showAlways(BuildContext context) async {
    if (!context.mounted) return false;
    return await _showDisclosureDialog(context);
  }

  /// Reset สถานะ (สำหรับ testing หรือ logout)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  static Future<bool> _showDisclosureDialog(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: colorScheme.scrim.withValues(alpha: 0.75),
      builder: (ctx) => const _LocationDisclosureDialog(),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    }

    return result ?? false;
  }
}

class _LocationDisclosureDialog extends StatelessWidget {
  const _LocationDisclosureDialog();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: colorScheme.onPrimary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'การเข้าถึงตำแหน่งที่ตั้ง',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Disclosure text — ข้อความตาม Google Play Policy
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: Text(
                  'JDC Delivery เก็บข้อมูลตำแหน่งที่ตั้งของคุณ '
                  'แม้ในขณะที่ปิดหน้าจอหรือไม่ได้ใช้งานแอป '
                  'เพื่อใช้ในการติดตามสถานะการจัดส่ง'
                  'และคำนวณระยะทาง',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              // Details
              _buildDetailRow(
                colorScheme,
                Icons.delivery_dining_rounded,
                'ติดตามสถานะการจัดส่ง',
                'แสดงตำแหน่งคนขับให้ลูกค้าและร้านค้าเห็นแบบเรียลไทม์',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                colorScheme,
                Icons.route_rounded,
                'คำนวณระยะทาง',
                'คำนวณค่าบริการตามระยะทางจริงระหว่างจุดรับ-ส่ง',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                colorScheme,
                Icons.shield_rounded,
                'ความปลอดภัย',
                'ข้อมูลตำแหน่งถูกเข้ารหัสและใช้เฉพาะในระบบเท่านั้น',
              ),
              const SizedBox(height: 24),

              // Accept button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                    shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    'ยอมรับและดำเนินการต่อ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Decline button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ไม่ยอมรับ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildDetailRow(
    ColorScheme colorScheme,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
