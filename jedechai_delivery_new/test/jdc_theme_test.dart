import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:jedechai_delivery_new/theme/jdc_colors.dart';
import 'package:jedechai_delivery_new/theme/jdc_layout.dart';
import 'package:jedechai_delivery_new/theme/theme_gallery_screen.dart';

/// คำนวณ contrast ratio ตามสูตร WCAG 2.1
double _contrast(Color a, Color b) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

  final la = luminance(a);
  final lb = luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// ฟิลด์ทั้งหมดของ JdcColors — ใช้ยืนยันว่า lerp/copyWith ไม่ลืมฟิลด์ไหน
/// ถ้าเพิ่มฟิลด์ใหม่แล้วลืมใส่ใน lerp เทสต์ "lerp ครบทุกฟิลด์" จะจับได้ทันที
final Map<String, Object? Function(JdcColors)> jdcFieldProbes = {
  'paper': (c) => c.paper,
  'surface': (c) => c.surface,
  'sunken': (c) => c.sunken,
  'line': (c) => c.line,
  'text': (c) => c.text,
  'muted': (c) => c.muted,
  'dim': (c) => c.dim,
  'panel': (c) => c.panel,
  'onPanel': (c) => c.onPanel,
  'panelDim': (c) => c.panelDim,
  'panelSoft': (c) => c.panelSoft,
  'panelSoft2': (c) => c.panelSoft2,
  'panelSoft3': (c) => c.panelSoft3,
  'panelLine': (c) => c.panelLine,
  'barDim': (c) => c.barDim,
  'brand': (c) => c.brand,
  'brandHi': (c) => c.brandHi,
  'cta': (c) => c.cta,
  'onCta': (c) => c.onCta,
  'link': (c) => c.link,
  'linkHover': (c) => c.linkHover,
  'brandSoft': (c) => c.brandSoft,
  'brandSoft2': (c) => c.brandSoft2,
  'brandLine': (c) => c.brandLine,
  'brandOnSoft': (c) => c.brandOnSoft,
  'successInk': (c) => c.successInk,
  'successSoft': (c) => c.successSoft,
  'successLine': (c) => c.successLine,
  'successFill': (c) => c.successFill,
  'successDot': (c) => c.successDot,
  'successOnPanel': (c) => c.successOnPanel,
  'successPanel': (c) => c.successPanel,
  'successPanelLine': (c) => c.successPanelLine,
  'infoSoft': (c) => c.infoSoft,
  'infoInk': (c) => c.infoInk,
  'danger': (c) => c.danger,
  'dangerInk': (c) => c.dangerInk,
  'dangerSoft': (c) => c.dangerSoft,
  'dangerLine': (c) => c.dangerLine,
  'offTrack': (c) => c.offTrack,
  'knob': (c) => c.knob,
  'trackEmpty': (c) => c.trackEmpty,
  'mapBg': (c) => c.mapBg,
  'mapGrid': (c) => c.mapGrid,
  'mapRoad': (c) => c.mapRoad,
  'route': (c) => c.route,
  'hero': (c) => c.hero,
  'hero2': (c) => c.hero2,
  'hero3': (c) => c.hero3,
  'shadowCard': (c) => c.shadowCard,
  'shadowRaise': (c) => c.shadowRaise,
  'shadowFloat': (c) => c.shadowFloat,
  'shadowDeep': (c) => c.shadowDeep,
  'shadowSheet': (c) => c.shadowSheet,
  'shadowBrand': (c) => c.shadowBrand,
  'shadowBrandLg': (c) => c.shadowBrandLg,
};

void main() {
  group('JdcColors', () {
    test('ธีมสว่างและมืดลงทะเบียน extension ครบ', () {
      expect(AppTheme.lightTheme.extension<JdcColors>(), isNotNull);
      expect(AppTheme.darkTheme.extension<JdcColors>(), isNotNull);
    });

    test('ชุดสีสองโหมดต้องไม่เหมือนกัน', () {
      expect(JdcColors.light.paper, isNot(JdcColors.dark.paper));
      expect(JdcColors.light.surface, isNot(JdcColors.dark.surface));
      expect(JdcColors.light.text, isNot(JdcColors.dark.text));
    });

    test('lerp ครบทุกฟิลด์ (t=1 ต้องได้ค่าของโหมดมืดเป๊ะ)', () {
      final end = JdcColors.light.lerp(JdcColors.dark, 1.0);
      final missing = <String>[];
      jdcFieldProbes.forEach((name, read) {
        final got = read(end);
        final want = read(JdcColors.dark);
        if (got is List<BoxShadow> && want is List<BoxShadow>) {
          if (got.length != want.length || got.first.color != want.first.color) {
            missing.add(name);
          }
        } else if (got != want) {
          missing.add(name);
        }
      });
      expect(missing, isEmpty,
          reason: 'ฟิลด์เหล่านี้ไม่ได้ถูก lerp: ' + missing.join(', '));
      expect(jdcFieldProbes.length, 56);
    });

    test('lerp ทำงานได้ทุกฟิลด์ ไม่คืนค่าว่าง', () {
      final mid = JdcColors.light.lerp(JdcColors.dark, 0.5);
      expect(mid, isA<JdcColors>());
      expect(mid.hero, isA<LinearGradient>());
      expect(mid.shadowCard, isNotEmpty);
      expect(JdcColors.light.lerp(null, 0.5), same(JdcColors.light));
    });

    test('copyWith เปลี่ยนเฉพาะฟิลด์ที่ส่งมา', () {
      final changed = JdcColors.light.copyWith(brand: const Color(0xFF000000));
      expect(changed.brand, const Color(0xFF000000));
      expect(changed.surface, JdcColors.light.surface);
    });

    test('พื้นการ์ดโหมดสว่างต้องเป็นขาวล้วนตาม decision ของดีไซน์', () {
      expect(JdcColors.light.surface, const Color(0xFFFFFFFF));
    });
  });

  group('contrast ตามกฎ a11y ของดีไซน์', () {
    test('ตัวอักษรหลักบนพื้นการ์ดผ่าน 4.5:1 ทั้งสองโหมด', () {
      expect(_contrast(JdcColors.light.text, JdcColors.light.surface),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(JdcColors.dark.text, JdcColors.dark.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('ตัวอักษรรองผ่าน 4.5:1 ทั้งสองโหมด', () {
      expect(_contrast(JdcColors.light.muted, JdcColors.light.surface),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(JdcColors.dark.muted, JdcColors.dark.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('ปุ่มหลักและลิงก์ผ่าน 4.5:1', () {
      expect(_contrast(JdcColors.light.onCta, JdcColors.light.cta),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(JdcColors.light.link, JdcColors.light.surface),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(JdcColors.dark.link, JdcColors.dark.surface),
          greaterThanOrEqualTo(4.5));
      // โหมดมืดเฉียดเกณฑ์ (~4.6:1) ถ้าวันไหนขยับสีทองจะ fail ทันที
      expect(_contrast(JdcColors.dark.onCta, JdcColors.dark.cta),
          greaterThanOrEqualTo(4.5));
    });

    test('ทองสดไม่ผ่านเกณฑ์บนพื้นขาว จึงต้องใช้เป็นพื้นเท่านั้น', () {
      // เทสต์นี้ยืนยันเหตุผลเบื้องหลัง decision ถ้าวันไหนมันผ่าน แปลว่าเปลี่ยนสีแล้ว
      expect(_contrast(JdcColors.light.brand, JdcColors.light.surface),
          lessThan(4.5));
    });
  });

group('ฟอนต์', () {
    test('หัวเรื่องใช้ IBM Plex Sans Thai เนื้อหาใช้ Noto Sans Thai', () {
      final t = AppTheme.lightTheme.textTheme;
      expect(t.headlineMedium?.fontFamily, 'IBMPlexSansThai');
      expect(t.bodyMedium?.fontFamily, 'NotoSansThai');
    });

    test('มีฟอนต์สำรองเสมอ เผื่อไฟล์ฟอนต์โหลดไม่ขึ้น', () {
      final t = AppTheme.lightTheme.textTheme;
      expect(t.bodyMedium?.fontFamilyFallback, isNotEmpty);
      expect(t.headlineMedium?.fontFamilyFallback, contains('Thonburi'));
      expect(AppTheme.darkTheme.textTheme.bodyMedium?.fontFamilyFallback,
          isNotEmpty);
    });

    test('Noto เป็น variable font จึงต้องส่งแกน wght คู่กับ fontWeight', () {
      final label = AppTheme.lightTheme.textTheme.labelLarge!;
      expect(label.fontVariations, isNotNull);
      expect(label.fontVariations!.first.axis, 'wght');
      expect(label.fontVariations!.first.value, label.fontWeight!.value.toDouble());
    });
  });

  group('responsive', () {
    test('จำแนกขนาดหน้าจอถูกต้อง', () {
      expect(JdcBreakpoints.classify(390), JdcWindowClass.compact);
      expect(JdcBreakpoints.classify(599), JdcWindowClass.compact);
      expect(JdcBreakpoints.classify(600), JdcWindowClass.medium);
      expect(JdcBreakpoints.classify(840), JdcWindowClass.expanded);
      expect(JdcBreakpoints.classify(1440), JdcWindowClass.large);
    });
  });

  group('Theme Gallery', () {
    Future<void> pumpAt(WidgetTester tester, Size size, ThemeData theme) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: const ThemeGalleryScreen()),
      );
      await tester.pump();
    }

    testWidgets('เปิดได้ในโหมดสว่าง', (tester) async {
      await pumpAt(tester, const Size(390, 844), AppTheme.lightTheme);
      expect(find.text('JDC Theme Gallery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('เปิดได้ในโหมดมืด', (tester) async {
      await pumpAt(tester, const Size(390, 844), AppTheme.darkTheme);
      expect(tester.takeException(), isNull);
    });

    testWidgets('เปิดได้บนจอแท็บเล็ตและจอกว้าง', (tester) async {
      await pumpAt(tester, const Size(834, 1112), AppTheme.lightTheme);
      expect(tester.takeException(), isNull);
      await pumpAt(tester, const Size(1440, 900), AppTheme.lightTheme);
      expect(tester.takeException(), isNull);
    });
  });
}
