import 'package:flutter/material.dart';

import 'jdc_palette.dart';

/// Token สีเชิงความหมายของ JDC — ใช้ตัวนี้ในหน้าจอทุกจุด ห้ามเรียก [JdcPalette] ตรง ๆ
///
/// วิธีใช้:
/// ```dart
/// final jdc = JdcColors.of(context);
/// Container(color: jdc.surface, child: Text('…', style: TextStyle(color: jdc.muted)));
/// ```
///
/// ค่าทุกตัวสลับตามโหมดสว่าง/มืดให้เอง ผ่าน [ThemeExtension]
/// ไฟล์นี้ถูกล็อกหลัง Wave 0 — ถ้าต้องการ token ใหม่ ให้หยุดและแจ้งผู้ดูแลธีม ห้ามเพิ่มเอง
@immutable
class JdcColors extends ThemeExtension<JdcColors> {
  const JdcColors({
    required this.paper,
    required this.surface,
    required this.sunken,
    required this.line,
    required this.text,
    required this.muted,
    required this.dim,
    required this.panel,
    required this.onPanel,
    required this.panelDim,
    required this.panelSoft,
    required this.panelSoft2,
    required this.panelSoft3,
    required this.panelLine,
    required this.barDim,
    required this.brand,
    required this.brandHi,
    required this.cta,
    required this.onCta,
    required this.link,
    required this.linkHover,
    required this.brandSoft,
    required this.brandSoft2,
    required this.brandLine,
    required this.brandOnSoft,
    required this.successInk,
    required this.successSoft,
    required this.successLine,
    required this.successFill,
    required this.successDot,
    required this.successOnPanel,
    required this.successPanel,
    required this.successPanelLine,
    required this.infoSoft,
    required this.infoInk,
    required this.danger,
    required this.dangerInk,
    required this.dangerSoft,
    required this.dangerLine,
    required this.offTrack,
    required this.knob,
    required this.trackEmpty,
    required this.mapBg,
    required this.mapGrid,
    required this.mapRoad,
    required this.route,
    required this.hero,
    required this.hero2,
    required this.hero3,
    required this.shadowCard,
    required this.shadowRaise,
    required this.shadowFloat,
    required this.shadowDeep,
    required this.shadowSheet,
    required this.shadowBrand,
    required this.shadowBrandLg,
  });

  // พื้นผิว
  final Color paper;
  final Color surface;
  final Color sunken;
  final Color line;

  // ตัวอักษร
  final Color text;
  final Color muted;
  final Color dim;

  // แถบเข้ม
  final Color panel;
  final Color onPanel;
  final Color panelDim;
  final Color panelSoft;
  final Color panelSoft2;
  final Color panelSoft3;
  final Color panelLine;
  final Color barDim;

  // แบรนด์ ทอง และปุ่มหลัก
  final Color brand;
  final Color brandHi;
  final Color cta;
  final Color onCta;
  final Color link;
  final Color linkHover;
  final Color brandSoft;
  final Color brandSoft2;
  final Color brandLine;
  final Color brandOnSoft;

  // สถานะสำเร็จ
  final Color successInk;
  final Color successSoft;
  final Color successLine;
  final Color successFill;
  final Color successDot;
  final Color successOnPanel;
  final Color successPanel;
  final Color successPanelLine;

  // ข้อมูล
  final Color infoSoft;
  final Color infoInk;

  // อันตราย
  final Color danger;
  final Color dangerInk;
  final Color dangerSoft;
  final Color dangerLine;

  // ตัวควบคุม
  final Color offTrack;
  final Color knob;
  final Color trackEmpty;

  // แผนที่
  final Color mapBg;
  final Color mapGrid;
  final Color mapRoad;
  final Color route;

  // ไล่สีหัวเรื่อง
  final LinearGradient hero;
  final LinearGradient hero2;
  final LinearGradient hero3;

  // เงา
  final List<BoxShadow> shadowCard;
  final List<BoxShadow> shadowRaise;
  final List<BoxShadow> shadowFloat;
  final List<BoxShadow> shadowDeep;
  final List<BoxShadow> shadowSheet;
  final List<BoxShadow> shadowBrand;
  final List<BoxShadow> shadowBrandLg;

  static const JdcColors light = JdcColors(
    paper: JdcPalette.lightPaper,
    surface: JdcPalette.lightSurface,
    sunken: JdcPalette.lightSunken,
    line: JdcPalette.lightLine,
    text: JdcPalette.lightText,
    muted: JdcPalette.lightMuted,
    dim: JdcPalette.lightDim,
    panel: JdcPalette.lightPanel,
    onPanel: JdcPalette.lightOnPanel,
    panelDim: JdcPalette.lightPanelDim,
    panelSoft: JdcPalette.lightPanelSoft,
    panelSoft2: JdcPalette.lightPanelSoft2,
    panelSoft3: JdcPalette.lightPanelSoft3,
    panelLine: JdcPalette.lightPanelLine,
    barDim: JdcPalette.lightBarDim,
    brand: JdcPalette.lightBrand,
    brandHi: JdcPalette.lightBrandHi,
    cta: JdcPalette.lightCta,
    onCta: JdcPalette.lightOnCta,
    link: JdcPalette.lightLink,
    linkHover: JdcPalette.lightLinkHover,
    brandSoft: JdcPalette.lightBrandSoft,
    brandSoft2: JdcPalette.lightBrandSoft2,
    brandLine: JdcPalette.lightBrandLine,
    brandOnSoft: JdcPalette.lightBrandOnSoft,
    successInk: JdcPalette.lightSuccessInk,
    successSoft: JdcPalette.lightSuccessSoft,
    successLine: JdcPalette.lightSuccessLine,
    successFill: JdcPalette.lightSuccessFill,
    successDot: JdcPalette.lightSuccessDot,
    successOnPanel: JdcPalette.lightSuccessOnPanel,
    successPanel: JdcPalette.lightSuccessPanel,
    successPanelLine: JdcPalette.lightSuccessPanelLine,
    infoSoft: JdcPalette.lightInfoSoft,
    infoInk: JdcPalette.lightInfoInk,
    danger: JdcPalette.lightDanger,
    dangerInk: JdcPalette.lightDangerInk,
    dangerSoft: JdcPalette.lightDangerSoft,
    dangerLine: JdcPalette.lightDangerLine,
    offTrack: JdcPalette.lightOffTrack,
    knob: JdcPalette.lightKnob,
    trackEmpty: JdcPalette.lightTrackEmpty,
    mapBg: JdcPalette.lightMapBg,
    mapGrid: JdcPalette.lightMapGrid,
    mapRoad: JdcPalette.lightMapRoad,
    route: JdcPalette.lightRoute,
    hero: JdcPalette.lightHero,
    hero2: JdcPalette.lightHero2,
    hero3: JdcPalette.lightHero3,
    shadowCard: JdcPalette.lightShadowCard,
    shadowRaise: JdcPalette.lightShadowRaise,
    shadowFloat: JdcPalette.lightShadowFloat,
    shadowDeep: JdcPalette.lightShadowDeep,
    shadowSheet: JdcPalette.lightShadowSheet,
    shadowBrand: JdcPalette.lightShadowBrand,
    shadowBrandLg: JdcPalette.lightShadowBrandLg,
  );

  static const JdcColors dark = JdcColors(
    paper: JdcPalette.darkPaper,
    surface: JdcPalette.darkSurface,
    sunken: JdcPalette.darkSunken,
    line: JdcPalette.darkLine,
    text: JdcPalette.darkText,
    muted: JdcPalette.darkMuted,
    dim: JdcPalette.darkDim,
    panel: JdcPalette.darkPanel,
    onPanel: JdcPalette.darkOnPanel,
    panelDim: JdcPalette.darkPanelDim,
    panelSoft: JdcPalette.darkPanelSoft,
    panelSoft2: JdcPalette.darkPanelSoft2,
    panelSoft3: JdcPalette.darkPanelSoft3,
    panelLine: JdcPalette.darkPanelLine,
    barDim: JdcPalette.darkBarDim,
    brand: JdcPalette.darkBrand,
    brandHi: JdcPalette.darkBrandHi,
    cta: JdcPalette.darkCta,
    onCta: JdcPalette.darkOnCta,
    link: JdcPalette.darkLink,
    linkHover: JdcPalette.darkLinkHover,
    brandSoft: JdcPalette.darkBrandSoft,
    brandSoft2: JdcPalette.darkBrandSoft2,
    brandLine: JdcPalette.darkBrandLine,
    brandOnSoft: JdcPalette.darkBrandOnSoft,
    successInk: JdcPalette.darkSuccessInk,
    successSoft: JdcPalette.darkSuccessSoft,
    successLine: JdcPalette.darkSuccessLine,
    successFill: JdcPalette.darkSuccessFill,
    successDot: JdcPalette.darkSuccessDot,
    successOnPanel: JdcPalette.darkSuccessOnPanel,
    successPanel: JdcPalette.darkSuccessPanel,
    successPanelLine: JdcPalette.darkSuccessPanelLine,
    infoSoft: JdcPalette.darkInfoSoft,
    infoInk: JdcPalette.darkInfoInk,
    danger: JdcPalette.darkDanger,
    dangerInk: JdcPalette.darkDangerInk,
    dangerSoft: JdcPalette.darkDangerSoft,
    dangerLine: JdcPalette.darkDangerLine,
    offTrack: JdcPalette.darkOffTrack,
    knob: JdcPalette.darkKnob,
    trackEmpty: JdcPalette.darkTrackEmpty,
    mapBg: JdcPalette.darkMapBg,
    mapGrid: JdcPalette.darkMapGrid,
    mapRoad: JdcPalette.darkMapRoad,
    route: JdcPalette.darkRoute,
    hero: JdcPalette.darkHero,
    hero2: JdcPalette.darkHero2,
    hero3: JdcPalette.darkHero3,
    shadowCard: JdcPalette.darkShadowCard,
    shadowRaise: JdcPalette.darkShadowRaise,
    shadowFloat: JdcPalette.darkShadowFloat,
    shadowDeep: JdcPalette.darkShadowDeep,
    shadowSheet: JdcPalette.darkShadowSheet,
    shadowBrand: JdcPalette.darkShadowBrand,
    shadowBrandLg: JdcPalette.darkShadowBrandLg,
  );

  /// อ่าน token ของธีมปัจจุบัน — ถ้าหาไม่เจอจะคืนชุดโหมดสว่างแทนการโยน error
  static JdcColors of(BuildContext context) =>
      Theme.of(context).extension<JdcColors>() ?? JdcColors.light;

  @override
  JdcColors copyWith({
    Color? paper,
    Color? surface,
    Color? sunken,
    Color? line,
    Color? text,
    Color? muted,
    Color? dim,
    Color? panel,
    Color? onPanel,
    Color? panelDim,
    Color? panelSoft,
    Color? panelSoft2,
    Color? panelSoft3,
    Color? panelLine,
    Color? barDim,
    Color? brand,
    Color? brandHi,
    Color? cta,
    Color? onCta,
    Color? link,
    Color? linkHover,
    Color? brandSoft,
    Color? brandSoft2,
    Color? brandLine,
    Color? brandOnSoft,
    Color? successInk,
    Color? successSoft,
    Color? successLine,
    Color? successFill,
    Color? successDot,
    Color? successOnPanel,
    Color? successPanel,
    Color? successPanelLine,
    Color? infoSoft,
    Color? infoInk,
    Color? danger,
    Color? dangerInk,
    Color? dangerSoft,
    Color? dangerLine,
    Color? offTrack,
    Color? knob,
    Color? trackEmpty,
    Color? mapBg,
    Color? mapGrid,
    Color? mapRoad,
    Color? route,
    LinearGradient? hero,
    LinearGradient? hero2,
    LinearGradient? hero3,
    List<BoxShadow>? shadowCard,
    List<BoxShadow>? shadowRaise,
    List<BoxShadow>? shadowFloat,
    List<BoxShadow>? shadowDeep,
    List<BoxShadow>? shadowSheet,
    List<BoxShadow>? shadowBrand,
    List<BoxShadow>? shadowBrandLg,
  }) {
    return JdcColors(
      paper: paper ?? this.paper,
      surface: surface ?? this.surface,
      sunken: sunken ?? this.sunken,
      line: line ?? this.line,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      dim: dim ?? this.dim,
      panel: panel ?? this.panel,
      onPanel: onPanel ?? this.onPanel,
      panelDim: panelDim ?? this.panelDim,
      panelSoft: panelSoft ?? this.panelSoft,
      panelSoft2: panelSoft2 ?? this.panelSoft2,
      panelSoft3: panelSoft3 ?? this.panelSoft3,
      panelLine: panelLine ?? this.panelLine,
      barDim: barDim ?? this.barDim,
      brand: brand ?? this.brand,
      brandHi: brandHi ?? this.brandHi,
      cta: cta ?? this.cta,
      onCta: onCta ?? this.onCta,
      link: link ?? this.link,
      linkHover: linkHover ?? this.linkHover,
      brandSoft: brandSoft ?? this.brandSoft,
      brandSoft2: brandSoft2 ?? this.brandSoft2,
      brandLine: brandLine ?? this.brandLine,
      brandOnSoft: brandOnSoft ?? this.brandOnSoft,
      successInk: successInk ?? this.successInk,
      successSoft: successSoft ?? this.successSoft,
      successLine: successLine ?? this.successLine,
      successFill: successFill ?? this.successFill,
      successDot: successDot ?? this.successDot,
      successOnPanel: successOnPanel ?? this.successOnPanel,
      successPanel: successPanel ?? this.successPanel,
      successPanelLine: successPanelLine ?? this.successPanelLine,
      infoSoft: infoSoft ?? this.infoSoft,
      infoInk: infoInk ?? this.infoInk,
      danger: danger ?? this.danger,
      dangerInk: dangerInk ?? this.dangerInk,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerLine: dangerLine ?? this.dangerLine,
      offTrack: offTrack ?? this.offTrack,
      knob: knob ?? this.knob,
      trackEmpty: trackEmpty ?? this.trackEmpty,
      mapBg: mapBg ?? this.mapBg,
      mapGrid: mapGrid ?? this.mapGrid,
      mapRoad: mapRoad ?? this.mapRoad,
      route: route ?? this.route,
      hero: hero ?? this.hero,
      hero2: hero2 ?? this.hero2,
      hero3: hero3 ?? this.hero3,
      shadowCard: shadowCard ?? this.shadowCard,
      shadowRaise: shadowRaise ?? this.shadowRaise,
      shadowFloat: shadowFloat ?? this.shadowFloat,
      shadowDeep: shadowDeep ?? this.shadowDeep,
      shadowSheet: shadowSheet ?? this.shadowSheet,
      shadowBrand: shadowBrand ?? this.shadowBrand,
      shadowBrandLg: shadowBrandLg ?? this.shadowBrandLg,
    );
  }

  @override
  JdcColors lerp(ThemeExtension<JdcColors>? other, double t) {
    if (other is! JdcColors) return this;
    return JdcColors(
      paper: Color.lerp(paper, other.paper, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      line: Color.lerp(line, other.line, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      dim: Color.lerp(dim, other.dim, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      onPanel: Color.lerp(onPanel, other.onPanel, t)!,
      panelDim: Color.lerp(panelDim, other.panelDim, t)!,
      panelSoft: Color.lerp(panelSoft, other.panelSoft, t)!,
      panelSoft2: Color.lerp(panelSoft2, other.panelSoft2, t)!,
      panelSoft3: Color.lerp(panelSoft3, other.panelSoft3, t)!,
      panelLine: Color.lerp(panelLine, other.panelLine, t)!,
      barDim: Color.lerp(barDim, other.barDim, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandHi: Color.lerp(brandHi, other.brandHi, t)!,
      cta: Color.lerp(cta, other.cta, t)!,
      onCta: Color.lerp(onCta, other.onCta, t)!,
      link: Color.lerp(link, other.link, t)!,
      linkHover: Color.lerp(linkHover, other.linkHover, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      brandSoft2: Color.lerp(brandSoft2, other.brandSoft2, t)!,
      brandLine: Color.lerp(brandLine, other.brandLine, t)!,
      brandOnSoft: Color.lerp(brandOnSoft, other.brandOnSoft, t)!,
      successInk: Color.lerp(successInk, other.successInk, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      successLine: Color.lerp(successLine, other.successLine, t)!,
      successFill: Color.lerp(successFill, other.successFill, t)!,
      successDot: Color.lerp(successDot, other.successDot, t)!,
      successOnPanel: Color.lerp(successOnPanel, other.successOnPanel, t)!,
      successPanel: Color.lerp(successPanel, other.successPanel, t)!,
      successPanelLine: Color.lerp(successPanelLine, other.successPanelLine, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      infoInk: Color.lerp(infoInk, other.infoInk, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerInk: Color.lerp(dangerInk, other.dangerInk, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      dangerLine: Color.lerp(dangerLine, other.dangerLine, t)!,
      offTrack: Color.lerp(offTrack, other.offTrack, t)!,
      knob: Color.lerp(knob, other.knob, t)!,
      trackEmpty: Color.lerp(trackEmpty, other.trackEmpty, t)!,
      mapBg: Color.lerp(mapBg, other.mapBg, t)!,
      mapGrid: Color.lerp(mapGrid, other.mapGrid, t)!,
      mapRoad: Color.lerp(mapRoad, other.mapRoad, t)!,
      route: Color.lerp(route, other.route, t)!,
      hero: LinearGradient.lerp(hero, other.hero, t)!,
      hero2: LinearGradient.lerp(hero2, other.hero2, t)!,
      hero3: LinearGradient.lerp(hero3, other.hero3, t)!,
      shadowCard: BoxShadow.lerpList(shadowCard, other.shadowCard, t)!,
      shadowRaise: BoxShadow.lerpList(shadowRaise, other.shadowRaise, t)!,
      shadowFloat: BoxShadow.lerpList(shadowFloat, other.shadowFloat, t)!,
      shadowDeep: BoxShadow.lerpList(shadowDeep, other.shadowDeep, t)!,
      shadowSheet: BoxShadow.lerpList(shadowSheet, other.shadowSheet, t)!,
      shadowBrand: BoxShadow.lerpList(shadowBrand, other.shadowBrand, t)!,
      shadowBrandLg: BoxShadow.lerpList(shadowBrandLg, other.shadowBrandLg, t)!,
    );
  }
}
