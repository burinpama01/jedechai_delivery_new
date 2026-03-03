import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class LanguageSwitcher extends StatelessWidget {
  final bool showSystemOption;

  const LanguageSwitcher({
    super.key,
    this.showSystemOption = true,
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
