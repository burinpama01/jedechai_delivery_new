import 'package:flutter/material.dart';

import 'jdc_colors.dart';
import 'jdc_layout.dart';
import 'jdc_palette.dart';

/// ธีมกลางของ JDC — ประกอบ [ColorScheme] และลงทะเบียน [JdcColors]
///
/// สีทั้งหมดมาจาก `jdc_palette.dart` ซึ่งตรงกับแคนวาสดีไซน์ 1:1
/// หน้าจอ **ห้าม** อ้างค่าสีจากไฟล์นี้โดยตรง ให้ใช้ `JdcColors.of(context)` แทน
/// เพราะค่าใน [AppTheme] ที่เหลือเป็นเพียงสะพานชั่วคราวของโค้ดเดิม
class AppTheme {
  // ------------------------------------------------------------------
  // สะพานชั่วคราวสำหรับโค้ดเดิม (จะถูกลบใน Wave 2)
  //
  // ชื่อเดิมคลาดเคลื่อนจากค่าจริงมาตลอด เช่น primaryGreen มีค่าเป็นสีทอง
  // จึงคงชื่อไว้ก่อนเพื่อไม่ให้ 568 จุดเรียกใช้พังพร้อมกัน แล้วย้ายทีละโฟลเดอร์
  // ------------------------------------------------------------------

  @Deprecated('ใช้ JdcColors.of(context).cta แทน — จะถูกลบใน Wave 2')
  static const Color primaryGreen = JdcPalette.lightCta;

  @Deprecated('ใช้ JdcColors.of(context).linkHover แทน — จะถูกลบใน Wave 2')
  static const Color primaryGreenDark = JdcPalette.lightLinkHover;

  @Deprecated('ใช้ JdcColors.of(context).brand แทน — จะถูกลบใน Wave 2')
  static const Color primaryGreenLight = JdcPalette.lightBrand;

  @Deprecated('ใช้ JdcColors.of(context).brand แทน — จะถูกลบใน Wave 2')
  static const Color accentOrange = JdcPalette.lightBrand;

  @Deprecated('ใช้ JdcColors.of(context).infoInk แทน — จะถูกลบใน Wave 2')
  static const Color accentBlue = JdcPalette.lightInfoInk;

  @Deprecated('ใช้ JdcColors.of(context).text แทน — จะถูกลบใน Wave 2')
  static const Color textPrimary = JdcPalette.lightText;

  @Deprecated('ใช้ JdcColors.of(context).muted แทน — จะถูกลบใน Wave 2')
  static const Color textSecondary = JdcPalette.lightMuted;

  @Deprecated('ใช้ JdcColors.of(context).paper แทน — จะถูกลบใน Wave 2')
  static const Color backgroundLight = JdcPalette.lightPaper;

  @Deprecated('ใช้ JdcColors.of(context).surface แทน — จะถูกลบใน Wave 2')
  static const Color backgroundWhite = JdcPalette.lightSurface;

  @Deprecated('ใช้ JdcColors.of(context).text แทน — จะถูกลบใน Wave 2')
  static const Color darkTextPrimary = JdcPalette.darkText;

  @Deprecated('ใช้ JdcColors.of(context).muted แทน — จะถูกลบใน Wave 2')
  static const Color darkTextSecondary = JdcPalette.darkMuted;

  // ------------------------------------------------------------------
  // ธีม
  // ------------------------------------------------------------------

  static ThemeData get lightTheme => _build(JdcColors.light, Brightness.light);

  static ThemeData get darkTheme => _build(JdcColors.dark, Brightness.dark);

  static ColorScheme _scheme(JdcColors c, Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: c.cta,
      onPrimary: c.onCta,
      primaryContainer: c.brandSoft,
      onPrimaryContainer: c.brandOnSoft,
      secondary: c.panel,
      onSecondary: c.onPanel,
      secondaryContainer: c.infoSoft,
      onSecondaryContainer: c.infoInk,
      tertiary: c.successFill,
      // successFill เขียวเข้มพอให้ตัวอักษรขาวผ่าน contrast 4.5:1 ทั้งสองโหมด
      onTertiary: Colors.white,
      tertiaryContainer: c.successSoft,
      onTertiaryContainer: c.successInk,
      error: c.danger,
      onError: brightness == Brightness.light ? Colors.white : c.paper,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.dangerInk,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.paper,
      surfaceContainer: c.sunken,
      surfaceContainerHigh: c.sunken,
      // ชั้นสูงสุดยืมค่า line มาใช้ชั่วคราว เพราะดีไซน์ยังไม่ได้กำหนดพื้นระดับนี้
      surfaceContainerHighest: c.line,
      onSurfaceVariant: c.muted,
      outline: c.line,
      // เส้นบางกว่า outline (Divider, ขอบ Chip) ตามลำดับชั้นของ M3
      outlineVariant: c.trackEmpty,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: c.panel,
      onInverseSurface: c.onPanel,
      inversePrimary: c.brand,
    );
  }

  /// ตัวอักษร: หัวเรื่องใช้ IBM Plex Sans Thai เนื้อหาใช้ Noto Sans Thai
  ///
  /// ทั้งสองตระกูลถูก bundle ไว้ใน `assets/fonts/` และมี [JdcPalette.fontFallback]
  /// เป็นฟอนต์สำรอง เผื่อไฟล์โหลดไม่ขึ้นหรือเจออักขระที่ฟอนต์หลักไม่มี
  ///
  /// Noto Sans Thai เป็น variable font — `fontWeight` อย่างเดียวไม่ทำให้หนาขึ้น
  /// ต้องส่ง [FontVariation] แกน `wght` คู่กันเสมอ
  static TextTheme _textTheme(JdcColors c) {
    TextStyle display(double size, FontWeight weight) => TextStyle(
          fontFamily: JdcPalette.fontDisplay,
          fontFamilyFallback: JdcPalette.fontFallback,
          fontSize: size,
          fontWeight: weight,
          color: c.text,
          height: 1.35,
        );
    TextStyle body(double size, FontWeight weight) => TextStyle(
          fontFamily: JdcPalette.fontBody,
          fontFamilyFallback: JdcPalette.fontFallback,
          fontSize: size,
          fontWeight: weight,
          fontVariations: [
            FontVariation('wght', weight.value.toDouble()),
          ],
          color: c.text,
          height: 1.5,
        );

    return TextTheme(
      displayLarge: display(30, FontWeight.w700),
      displayMedium: display(26, FontWeight.w700),
      displaySmall: display(22, FontWeight.w700),
      headlineLarge: display(22, FontWeight.w700),
      headlineMedium: display(20, FontWeight.w700),
      headlineSmall: display(18, FontWeight.w700),
      titleLarge: display(17, FontWeight.w700),
      titleMedium: display(15, FontWeight.w700),
      titleSmall: body(14, FontWeight.w600),
      bodyLarge: body(15, FontWeight.w400),
      bodyMedium: body(14, FontWeight.w400),
      bodySmall: body(12, FontWeight.w400).copyWith(color: c.muted),
      labelLarge: body(14, FontWeight.w700),
      labelMedium: body(12, FontWeight.w600),
      labelSmall: body(11, FontWeight.w600).copyWith(color: c.muted),
    );
  }

  static ThemeData _build(JdcColors c, Brightness brightness) {
    final scheme = _scheme(c, brightness);
    final text = _textTheme(c);

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(JdcRadius.field),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      dividerColor: c.line,
      fontFamily: JdcPalette.fontBody,
      fontFamilyFallback: JdcPalette.fontFallback,
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: IconThemeData(color: c.text, size: 22),
      primaryIconTheme: IconThemeData(color: c.onPanel, size: 22),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.panel,
        foregroundColor: c.onPanel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: c.onPanel),
        iconTheme: IconThemeData(color: c.onPanel),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.cta,
          foregroundColor: c.onCta,
          disabledBackgroundColor: c.sunken,
          disabledForegroundColor: c.muted,
          elevation: 0,
          minimumSize: const Size(0, JdcTouch.button),
          padding: const EdgeInsets.symmetric(horizontal: JdcSpacing.xxl),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card - 2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          backgroundColor: c.surface,
          minimumSize: const Size(0, JdcTouch.button),
          padding: const EdgeInsets.symmetric(horizontal: JdcSpacing.xxl),
          side: BorderSide(color: c.line),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card - 2),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.link,
          minimumSize: const Size(0, JdcTouch.minTarget),
          textStyle: text.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.cta,
          foregroundColor: c.onCta,
          minimumSize: const Size(0, JdcTouch.button),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card - 2),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        constraints: const BoxConstraints(minHeight: JdcTouch.field),
        labelStyle: TextStyle(color: c.muted),
        hintStyle: TextStyle(color: c.dim),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        border: border(c.line),
        enabledBorder: border(c.line),
        focusedBorder: border(c.cta, 2),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: JdcSpacing.lg,
          vertical: JdcSpacing.md,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.line),
          borderRadius: BorderRadius.circular(JdcRadius.card),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.panel,
        side: BorderSide(color: c.line),
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium?.copyWith(color: c.onPanel),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: JdcSpacing.md,
          vertical: JdcSpacing.sm,
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: c.text,
        iconColor: c.muted,
        minVerticalPadding: JdcSpacing.md,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.card),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(c.knob),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.successFill
              : c.offTrack,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.cta,
        linearTrackColor: c.trackEmpty,
        circularTrackColor: c.trackEmpty,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.link,
        unselectedItemColor: c.muted,
        selectedLabelStyle: text.labelSmall?.copyWith(
          color: c.link,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: text.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.brandSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(JdcRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.sheet),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.panel,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onPanel),
        actionTextColor: c.brandHi,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.small),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.link,
        unselectedLabelColor: c.muted,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelMedium,
        indicatorColor: c.cta,
        dividerColor: c.line,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.cta,
        foregroundColor: c.onCta,
      ),
    );
  }
}
