import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class LanguageSwitcher extends StatelessWidget {
  final bool showSystemOption;
  final Color? selectedColor;

  const LanguageSwitcher({
    super.key,
    this.showSystemOption = true,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LanguageProvider>();
    final current = provider.localeOverride;
    final l10n = AppLocalizations.of(context);

    String value;
    if (current == null) {
      value = 'system';
    } else if (current.languageCode == 'th') {
      value = 'th';
    } else {
      value = 'en';
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        iconEnabledColor: selectedColor,
        onChanged: (v) async {
          if (v == null) return;
          final p = context.read<LanguageProvider>();
          if (v == 'system') {
            await p.useSystemLocale();
          } else if (v == 'th') {
            await p.useThai();
          } else {
            await p.useEnglish();
          }
        },
        // ปุ่มตอนปิดอยู่ต้องสั้น ไม่งั้นความกว้างจะถูกกำหนดโดยตัวเลือกที่ยาวที่สุด
        // ("ใช้ภาษาของระบบ") แล้วไปดัน Row ที่ครอบอยู่จนล้นบนจอแคบ
        selectedItemBuilder: (context) => [
          if (showSystemOption)
            Center(child: Text(l10n?.languageSystemShort ?? 'ระบบ', style: TextStyle(color: selectedColor))),
          Center(child: Text('TH', style: TextStyle(color: selectedColor))),
          Center(child: Text('EN', style: TextStyle(color: selectedColor))),
        ],
        items: [
          if (showSystemOption)
            DropdownMenuItem(
              value: 'system',
              child: Text(l10n?.useSystemLanguage ?? 'SYSTEM'),
            ),
          DropdownMenuItem(
            value: 'th',
            child: Text(l10n?.thai ?? 'TH'),
          ),
          DropdownMenuItem(
            value: 'en',
            child: Text(l10n?.english ?? 'EN'),
          ),
        ],
      ),
    );
  }
}
