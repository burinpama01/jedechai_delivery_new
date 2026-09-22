import 'package:flutter/material.dart';

/// ค่าสีดิบของ JDC — ตรงกับ CSS variable ในแคนวาสดีไซน์ 1:1
///
/// ที่มา: `Design/jdc-canvas/project/*.dc.html` (token block ใน `<helmet>`)
/// ห้ามใส่ logic ใด ๆ ในไฟล์นี้ และห้ามอ้างค่าจากไฟล์นี้ในหน้าจอโดยตรง
/// ให้ใช้ผ่าน `JdcColors` (lib/theme/jdc_colors.dart) เท่านั้น
/// เพราะค่าในนี้ไม่รู้ว่าตอนนี้แอปอยู่โหมดสว่างหรือมืด
class JdcPalette {
  const JdcPalette._();

  // ---------------------------------------------------------------- โหมดสว่าง
  // --paper --surface --sunken --line
  static const Color lightPaper = Color(0xFFF4F7F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSunken = Color(0xFFEEF2EE);
  static const Color lightLine = Color(0xFFDBE4DE);

  // --text --muted --dim
  static const Color lightText = Color(0xFF0F3B33);
  static const Color lightMuted = Color(0xFF5C6F68);
  static const Color lightDim = Color(0xFF66736D);

  // --panel --on-panel --panel-dim
  static const Color lightPanel = Color(0xFF0F3B33);
  static const Color lightOnPanel = Color(0xFFFFFFFF);
  static const Color lightPanelDim = Color(0xFFB7CFC8);

  // --panel-soft* --panel-line --bar-dim (พื้นโปร่งบนแถบเข้ม)
  static const Color lightPanelSoft = Color(0x1AFFFFFF);
  static const Color lightPanelSoft2 = Color(0x1FFFFFFF);
  static const Color lightPanelSoft3 = Color(0x24FFFFFF);
  static const Color lightPanelLine = Color(0x3DFFFFFF);
  static const Color lightBarDim = Color(0x42FFFFFF);

  // --brand --brand-hi --cta --on-cta --link --link-hover
  static const Color lightBrand = Color(0xFFE39C2E);
  static const Color lightBrandHi = Color(0xFFF3C06A);
  static const Color lightCta = Color(0xFF8A5A0A);
  static const Color lightOnCta = Color(0xFFFFFFFF);
  static const Color lightLink = Color(0xFF8A5A0A);
  static const Color lightLinkHover = Color(0xFF6D4708);

  // --brand-soft --brand-soft2 --brand-line --brand-on-soft
  static const Color lightBrandSoft = Color(0xFFFFF3DC);
  static const Color lightBrandSoft2 = Color(0xFFFFFAF0);
  static const Color lightBrandLine = Color(0xFFF0CF95);
  static const Color lightBrandOnSoft = Color(0xFF8A5A0A);

  // --green-* (สถานะสำเร็จ)
  static const Color lightSuccessInk = Color(0xFF2B6B2B);
  static const Color lightSuccessSoft = Color(0xFFE6F4E2);
  static const Color lightSuccessLine = Color(0xFFBFE0B6);
  static const Color lightSuccessFill = Color(0xFF2E7D43);
  static const Color lightSuccessDot = Color(0xFF5FCF7A);
  static const Color lightSuccessOnPanel = Color(0xFFA8E0B4);
  static const Color lightSuccessPanel = Color(0x4D2E7D43);
  static const Color lightSuccessPanelLine = Color(0x735FCF7A);

  // --teal-* (ป้ายข้อมูล)
  static const Color lightInfoSoft = Color(0xFFE2F1EF);
  static const Color lightInfoInk = Color(0xFF16605A);

  // --danger-*
  static const Color lightDanger = Color(0xFFB42318);
  static const Color lightDangerInk = Color(0xFF8F1C14);
  static const Color lightDangerSoft = Color(0xFFFFECE9);
  static const Color lightDangerLine = Color(0xFFF0B3AB);

  // --off-track --knob --track-empty (สวิตช์/แถบความคืบหน้า)
  static const Color lightOffTrack = Color(0xFFC3CCC6);
  static const Color lightKnob = Color(0xFFFFFFFF);
  static const Color lightTrackEmpty = Color(0xFFE1E8E3);

  // --map-* --route
  static const Color lightMapBg = Color(0xFFDFE7E2);
  static const Color lightMapGrid = Color(0xFFD4DED8);
  static const Color lightMapRoad = Color(0xFFFFFFFF);
  static const Color lightRoute = Color(0xFF8A5A0A);

  // ---------------------------------------------------------------- โหมดมืด
  static const Color darkPaper = Color(0xFF0B1A17);
  static const Color darkSurface = Color(0xFF12241F);
  static const Color darkSunken = Color(0xFF0E1F1B);
  static const Color darkLine = Color(0xFF24403A);

  static const Color darkText = Color(0xFFE8F1ED);
  static const Color darkMuted = Color(0xFF9CB1A9);
  static const Color darkDim = Color(0xFF8FA39C);

  static const Color darkPanel = Color(0xFF16352E);
  static const Color darkOnPanel = Color(0xFFF2F8F5);
  static const Color darkPanelDim = Color(0xFF9AB6AE);

  static const Color darkPanelSoft = Color(0x14FFFFFF);
  static const Color darkPanelSoft2 = Color(0x1AFFFFFF);
  static const Color darkPanelSoft3 = Color(0x1FFFFFFF);
  static const Color darkPanelLine = Color(0x2EFFFFFF);
  static const Color darkBarDim = Color(0x3DFFFFFF);

  static const Color darkBrand = Color(0xFFE0A53F);
  static const Color darkBrandHi = Color(0xFFF3C06A);
  static const Color darkCta = Color(0xFFA0690F);
  static const Color darkOnCta = Color(0xFFFFFFFF);
  static const Color darkLink = Color(0xFFEDBB62);
  static const Color darkLinkHover = Color(0xFFF6D493);

  static const Color darkBrandSoft = Color(0xFF2A2114);
  static const Color darkBrandSoft2 = Color(0xFF241D12);
  static const Color darkBrandLine = Color(0xFF4A3A1C);
  static const Color darkBrandOnSoft = Color(0xFFEDBB62);

  static const Color darkSuccessInk = Color(0xFF85CF82);
  static const Color darkSuccessSoft = Color(0xFF14301C);
  static const Color darkSuccessLine = Color(0xFF26512A);
  static const Color darkSuccessFill = Color(0xFF2E7D43);
  static const Color darkSuccessDot = Color(0xFF5FCF7A);
  static const Color darkSuccessOnPanel = Color(0xFFA8E0B4);
  static const Color darkSuccessPanel = Color(0x522E7D43);
  static const Color darkSuccessPanelLine = Color(0x665FCF7A);

  static const Color darkInfoSoft = Color(0xFF0F2A28);
  static const Color darkInfoInk = Color(0xFF6FC3BA);

  static const Color darkDanger = Color(0xFFFF8A7D);
  static const Color darkDangerInk = Color(0xFFFF9A8E);
  static const Color darkDangerSoft = Color(0xFF351A17);
  static const Color darkDangerLine = Color(0xFF55302B);

  static const Color darkOffTrack = Color(0xFF3A4D47);
  static const Color darkKnob = Color(0xFFF2F8F5);
  static const Color darkTrackEmpty = Color(0xFF24403A);

  static const Color darkMapBg = Color(0xFF17302A);
  static const Color darkMapGrid = Color(0xFF1E3B34);
  static const Color darkMapRoad = Color(0xFF25453D);
  static const Color darkRoute = Color(0xFFE0A53F);

  // ---------------------------------------------------------------- ไล่สีหัวเรื่อง
  /// --hero : ใช้กับหน้าลูกค้า/บัญชี
  static const LinearGradient lightHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E382F), Color(0xFF1D5F50), Color(0xFF8A5A0A)],
    stops: [0.0, 0.55, 1.0],
  );

  /// --hero2 : ใช้กับหน้าสำเร็จ/คนขับ
  static const LinearGradient lightHero2 = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E382F), Color(0xFF1A5548)],
    stops: [0.0, 0.7],
  );

  /// --hero3 : ใช้กับหน้าร้าน/อาหาร
  static const LinearGradient lightHero3 = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E382F), Color(0xFF20655A), Color(0xFF8A5A0A)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient darkHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A2621), Color(0xFF134137), Color(0xFF5E3F0B)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient darkHero2 = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A2621), Color(0xFF123B33)],
    stops: [0.0, 0.7],
  );

  static const LinearGradient darkHero3 = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A2621), Color(0xFF154439), Color(0xFF5E3F0B)],
    stops: [0.0, 0.55, 1.0],
  );

  // ---------------------------------------------------------------- เงา
  // --sh-card --sh-raise --sh-float --sh-deep --sh-sheet --sh-brand --sh-brand-lg
  static const List<BoxShadow> lightShadowCard = [
    BoxShadow(color: Color(0x120C2C25), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> lightShadowRaise = [
    BoxShadow(color: Color(0x1A0C2C25), blurRadius: 30, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> lightShadowFloat = [
    BoxShadow(color: Color(0x290C2C25), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> lightShadowDeep = [
    BoxShadow(color: Color(0x4D0C2C25), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> lightShadowSheet = [
    BoxShadow(color: Color(0x140C2C25), blurRadius: 30, offset: Offset(0, -10)),
  ];
  static const List<BoxShadow> lightShadowBrand = [
    BoxShadow(color: Color(0x38E39C2E), blurRadius: 26, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> lightShadowBrandLg = [
    BoxShadow(color: Color(0x42E39C2E), blurRadius: 34, offset: Offset(0, 14)),
  ];

  static const List<BoxShadow> darkShadowCard = [
    BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> darkShadowRaise = [
    BoxShadow(color: Color(0x73000000), blurRadius: 30, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> darkShadowFloat = [
    BoxShadow(color: Color(0x73000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> darkShadowDeep = [
    BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> darkShadowSheet = [
    BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, -10)),
  ];
  static const List<BoxShadow> darkShadowBrand = [
    BoxShadow(color: Color(0x73000000), blurRadius: 26, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> darkShadowBrandLg = [
    BoxShadow(color: Color(0x80000000), blurRadius: 34, offset: Offset(0, 14)),
  ];

  // ---------------------------------------------------------------- ฟอนต์
  /// หัวเรื่อง (ตรงกับ class `.dsp` และ h1–h3 ในแคนวาส) — static 4 น้ำหนัก
  static const String fontDisplay = 'IBMPlexSansThai';

  /// เนื้อหา — เป็น variable font น้ำหนักคุมผ่าน `FontVariation('wght', …)`
  static const String fontBody = 'NotoSansThai';

  /// ฟอนต์สำรองเรียงตามลำดับ เผื่อไฟล์ฟอนต์โหลดไม่ขึ้นหรือมีอักขระที่ฟอนต์หลักไม่มี
  ///
  /// สองตัวแรกเป็นฟอนต์ไทยที่มากับ iOS/Android อยู่แล้ว ตัวท้ายเป็น sans ทั่วไป
  /// จุดประสงค์คือ "ตัวอักษรไทยต้องอ่านออกเสมอ" ไม่ใช่หน้าตาตรงเป๊ะ
  static const List<String> fontFallback = <String>[
    'Noto Sans Thai', // Android / ฟอนต์ระบบที่ติดตั้งเพิ่ม
    'Thonburi', // iOS / macOS
    'Sarabun', // ฟอนต์ราชการไทยที่หลายเครื่องมี
    'Roboto',
    'Arial',
  ];
}
