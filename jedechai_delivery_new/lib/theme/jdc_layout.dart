import 'package:flutter/material.dart';

import 'jdc_colors.dart';

/// ระดับความกว้างหน้าจอตามแนว Material 3 window size class
enum JdcWindowClass {
  /// มือถือแนวตั้ง (< 600)
  compact,

  /// มือถือแนวนอน / แท็บเล็ตเล็ก (600–839)
  medium,

  /// แท็บเล็ตใหญ่ (840–1199)
  expanded,

  /// เดสก์ท็อป / จอต่อพ่วง (>= 1200)
  large,
}

/// จุดตัดความกว้าง — ใช้ที่เดียวทั้งแอป ห้ามเขียนตัวเลขจุดตัดซ้ำในหน้าจอ
class JdcBreakpoints {
  const JdcBreakpoints._();

  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;

  /// ความกว้างที่ดีไซน์วาดไว้ (artboard) ใช้เป็นฐานคำนวณสัดส่วน
  static const double designWidth = 390;

  /// ความกว้างสูงสุดของเนื้อหาหลักบนจอใหญ่ — กันบรรทัดยาวจนอ่านยาก
  static const double readableMaxWidth = 560;

  /// ความกว้างสูงสุดของฟอร์ม/บทสนทนาบนจอใหญ่
  static const double formMaxWidth = 480;

  static JdcWindowClass classify(double width) {
    if (width >= large) return JdcWindowClass.large;
    if (width >= expanded) return JdcWindowClass.expanded;
    if (width >= medium) return JdcWindowClass.medium;
    return JdcWindowClass.compact;
  }
}

/// ระยะห่างมาตรฐาน (ตรงกับ gap ที่ใช้ในแคนวาส)
class JdcSpacing {
  const JdcSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// รัศมีมุมมาตรฐาน
class JdcRadius {
  const JdcRadius._();

  static const double chip = 999;
  static const double field = 14;
  static const double card = 18;
  static const double sheet = 22;
  static const double small = 12;
}

/// ความสูงขั้นต่ำของสิ่งที่กดได้ — ตามกฎ a11y ในดีไซน์
class JdcTouch {
  const JdcTouch._();

  static const double minTarget = 44;
  static const double button = 52;
  static const double field = 48;
}

/// ตัวช่วยเรื่องขนาดหน้าจอ เรียกผ่าน `context`
extension JdcContextX on BuildContext {
  /// token สีของธีมปัจจุบัน
  JdcColors get jdc => JdcColors.of(this);

  Size get screenSize => MediaQuery.sizeOf(this);

  JdcWindowClass get windowClass =>
      JdcBreakpoints.classify(MediaQuery.sizeOf(this).width);

  bool get isCompact => windowClass == JdcWindowClass.compact;
  bool get isTabletOrWider => windowClass != JdcWindowClass.compact;

  /// จอเตี้ยมาก (เช่นมือถือแนวนอน หรือเมื่อคีย์บอร์ดเด้ง) — ควรลดระยะห่าง
  bool get isShort => MediaQuery.sizeOf(this).height < 640;

  /// ระยะขอบซ้าย-ขวาของเนื้อหา ปรับตามความกว้างจอ
  double get gutter {
    switch (windowClass) {
      case JdcWindowClass.compact:
        return JdcSpacing.xl;
      case JdcWindowClass.medium:
        return JdcSpacing.xxl;
      case JdcWindowClass.expanded:
      case JdcWindowClass.large:
        return JdcSpacing.xxxl;
    }
  }

  /// จำนวนคอลัมน์ของกริดการ์ด
  int get gridColumns {
    switch (windowClass) {
      case JdcWindowClass.compact:
        return 1;
      case JdcWindowClass.medium:
        return 2;
      case JdcWindowClass.expanded:
        return 3;
      case JdcWindowClass.large:
        return 4;
    }
  }
}

/// ครอบเนื้อหาให้กว้างพอดีอ่าน และจัดกลางเมื่ออยู่บนจอกว้าง
///
/// ดีไซน์วาดบนกรอบ 390px ถ้าปล่อยให้ยืดเต็มจอแท็บเล็ตจะอ่านยากและสัดส่วนเพี้ยน
/// ใช้ widget นี้ครอบ body ของหน้าจอแทนการกำหนดความกว้างตายตัว
class JdcContentFrame extends StatelessWidget {
  const JdcContentFrame({
    super.key,
    required this.child,
    this.maxWidth = JdcBreakpoints.readableMaxWidth,
    this.padded = true,
  });

  final Widget child;
  final double maxWidth;

  /// ใส่ระยะขอบซ้าย-ขวาตาม [JdcContextX.gutter] ให้อัตโนมัติ
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
    if (!padded) return Center(child: content);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.gutter),
        child: content,
      ),
    );
  }
}

/// เลือกค่าตามขนาดจอแบบสั้น ๆ
///
/// ```dart
/// final cols = jdcByWidth(context, compact: 1, medium: 2, expanded: 3);
/// ```
T jdcByWidth<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
  T? large,
}) {
  switch (context.windowClass) {
    case JdcWindowClass.compact:
      return compact;
    case JdcWindowClass.medium:
      return medium ?? compact;
    case JdcWindowClass.expanded:
      return expanded ?? medium ?? compact;
    case JdcWindowClass.large:
      return large ?? expanded ?? medium ?? compact;
  }
}

/// จำกัดการขยายตัวอักษรของระบบไม่ให้ทำ layout แตก
///
/// ผู้ใช้ที่ตั้งฟอนต์ใหญ่มากยังอ่านได้ แต่ไม่ดันจนปุ่มล้นจอ
/// ใช้ใน `MaterialApp.builder` ที่เดียว
Widget jdcTextScaleGuard(BuildContext context, Widget? child) {
  final media = MediaQuery.of(context);
  return MediaQuery(
    data: media.copyWith(
      textScaler: media.textScaler.clamp(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.3,
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
