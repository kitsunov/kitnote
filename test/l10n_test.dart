import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/core/l10n/app_localizations.dart';
import 'package:kitnote/core/l10n/app_strings.dart';

void main() {
  group('AppStrings Localization Tests', () {
    const supportedCodes = ['sk', 'en', 'es', 'pt', 'zh', 'ru'];

    test('All 6 requested languages are registered and retrievable', () {
      for (final code in supportedCodes) {
        final strings = AppStrings.of(code);
        expect(strings, isNotNull);
        expect(strings.appTitle, equals('KitNote'));
        expect(strings.searchHint, isNotEmpty);
        expect(strings.importPdf, isNotEmpty);
        expect(strings.signIn, isNotEmpty);
        expect(strings.syncing, isNotEmpty);
        expect(strings.googleDrive, isNotEmpty);
        expect(strings.checkUpdates, isNotEmpty);
        expect(strings.newNotebook, isNotEmpty);
        expect(strings.folders, isNotEmpty);
        expect(strings.allNotebooks, isNotEmpty);
        expect(strings.newFolder, isNotEmpty);
        expect(strings.folderNameHint, isNotEmpty);
        expect(strings.noNotebooks, isNotEmpty);
        expect(strings.pen, isNotEmpty);
        expect(strings.highlighter, isNotEmpty);
        expect(strings.strokeEraser, isNotEmpty);
        expect(strings.pixelEraser, isNotEmpty);
        expect(strings.lasso, isNotEmpty);
        expect(strings.ruler, isNotEmpty);
        expect(strings.text, isNotEmpty);
        expect(strings.photo, isNotEmpty);
        expect(strings.colorPalette, isNotEmpty);
        expect(strings.palmRejectionOn, isNotEmpty);
        expect(strings.palmRejectionOff, isNotEmpty);
        expect(strings.page, isNotEmpty);
        expect(strings.addPage, isNotEmpty);
        expect(strings.duplicatePage, isNotEmpty);
        expect(strings.deletePage, isNotEmpty);
        expect(strings.exportPdf, isNotEmpty);
        expect(strings.deleteNotebook, isNotEmpty);
        expect(strings.splitScreen, isNotEmpty);
        expect(strings.updateAvailable, isNotEmpty);
        expect(strings.updateNow, isNotEmpty);
        expect(strings.later, isNotEmpty);
        expect(strings.whatsNew, isNotEmpty);
        expect(strings.downloadUpdate, isNotEmpty);
        expect(strings.language, isNotEmpty);
        expect(strings.retry, isNotEmpty);
        expect(strings.failedToLoadPage, isNotEmpty);
        expect(strings.saved, isNotEmpty);
        expect(strings.saving, isNotEmpty);
        expect(strings.saveError, isNotEmpty);
      }
    });

    test('Fallback to Russian for unsupported locale code', () {
      final fallbackStrings = AppStrings.of('de');
      expect(fallbackStrings, equals(AppStrings.ru));
      expect(fallbackStrings.newNotebook, equals('Новая тетрадь'));
    });

    test('Specific languages contain accurate translations', () {
      // Slovak (sk)
      const sk = AppStrings.sk;
      expect(sk.newNotebook, equals('Nový zošit'));
      expect(sk.folders, equals('Priečinky'));
      expect(sk.allNotebooks, equals('Všetky zošity'));

      // English (en)
      const en = AppStrings.en;
      expect(en.newNotebook, equals('New Notebook'));
      expect(en.folders, equals('Folders'));

      // Spanish (es)
      const es = AppStrings.es;
      expect(es.newNotebook, equals('Nuevo cuaderno'));
      expect(es.folders, equals('Carpetas'));

      // Portuguese (pt)
      const pt = AppStrings.pt;
      expect(pt.newNotebook, equals('Novo caderno'));
      expect(pt.folders, equals('Pastas'));

      // Chinese (zh)
      const zh = AppStrings.zh;
      expect(zh.newNotebook, equals('新建笔记本'));
      expect(zh.folders, equals('文件夹'));

      // Russian (ru)
      const ru = AppStrings.ru;
      expect(ru.newNotebook, equals('Новая тетрадь'));
      expect(ru.folders, equals('Папки'));
    });

    test('AppLocalizations language display names are correct', () {
      expect(AppLocalizations.getLanguageName('sk'), equals('Slovenčina'));
      expect(AppLocalizations.getLanguageName('en'), equals('English'));
      expect(AppLocalizations.getLanguageName('es'), equals('Español'));
      expect(AppLocalizations.getLanguageName('pt'), equals('Português'));
      expect(AppLocalizations.getLanguageName('zh'), equals('中文 (简体)'));
      expect(AppLocalizations.getLanguageName('ru'), equals('Русский'));
    });
  });
}
