import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _prefsKey = 'locale_override';

  Locale? _localeOverride;
  bool _loaded = false;

  Locale? get localeOverride => _localeOverride;
  bool get loaded => _loaded;

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);

      if (raw == null || raw.isEmpty) {
        _localeOverride = null;
      } else {
        final parts = raw.split('_');
        if (parts.isNotEmpty) {
          _localeOverride = Locale(parts[0], parts.length > 1 ? parts[1] : null);
        }
      }
    } catch (_) {
      _localeOverride = null;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setLocaleOverride(Locale? locale) async {
    _localeOverride = locale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.setString(_prefsKey, '');
      } else {
        final raw = [locale.languageCode, if (locale.countryCode?.isNotEmpty == true) locale.countryCode].join('_');
        await prefs.setString(_prefsKey, raw);
      }
    } catch (_) {
      // Ignore persistence errors.
    }
  }

  Future<void> useSystemLocale() => setLocaleOverride(null);

  Future<void> useThai() => setLocaleOverride(const Locale('th', 'TH'));

  Future<void> useEnglish() => setLocaleOverride(const Locale('en', 'US'));
}
