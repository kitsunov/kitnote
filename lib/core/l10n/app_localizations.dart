import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

class AppLocalizations {
  final Locale locale;
  final AppStrings strings;

  AppLocalizations(this.locale) : strings = AppStrings.of(locale.languageCode);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('sk', 'SK'), // Slovak
    Locale('en', 'US'), // English
    Locale('es', 'ES'), // Spanish
    Locale('pt', 'BR'), // Portuguese
    Locale('zh', 'CN'), // Chinese
    Locale('ru', 'RU'), // Russian
  ];

  static String getLanguageName(String code) {
    switch (code) {
      case 'sk':
        return 'Slovenčina';
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'pt':
        return 'Português';
      case 'zh':
        return '中文 (简体)';
      case 'ru':
        return 'Русский';
      default:
        return code;
    }
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['sk', 'en', 'es', 'pt', 'zh', 'ru'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  LocaleProvider() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('app_language_code');
      if (code != null) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale newLocale) async {
    _locale = newLocale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language_code', newLocale.languageCode);
    } catch (_) {}
  }
}
