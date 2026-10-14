import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'state/library_state.dart';
import 'state/workspace_state.dart';
import 'ui/editor/notebook_editor_view.dart';
import 'ui/library/library_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[KitNote ErrorBoundary] Flutter error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[KitNote ErrorBoundary] Unhandled async error: $error\n$stack');
    return true;
  };

  runApp(const KitNoteApp());
}

class KitNoteApp extends StatelessWidget {
  const KitNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => LibraryState()),
        ChangeNotifierProvider(create: (_) => WorkspaceState()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'KitNote',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppRootNavigator(),
          );
        },
      ),
    );
  }
}

class AppRootNavigator extends StatelessWidget {
  const AppRootNavigator({super.key});

  void _openLibraryOverlay(BuildContext context, WorkspaceState workspace) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => LibraryScreen(
          onOpenNotebook: (id) {
            workspace.openNotebook(id);
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceState>(context);

    // If there are active open notebook tabs, show editor; else library
    if (workspace.openNotebookIds.isNotEmpty) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _openLibraryOverlay(context, workspace);
          }
        },
        child: NotebookEditorView(
          onBackToLibrary: () => _openLibraryOverlay(context, workspace),
        ),
      );
    }

    return LibraryScreen(
      onOpenNotebook: (id) {
        workspace.openNotebook(id);
      },
    );
  }
}
