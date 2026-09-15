import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'state/library_state.dart';
import 'state/workspace_state.dart';
import 'ui/editor/notebook_editor_view.dart';
import 'ui/library/library_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KitNoteApp());
}

class KitNoteApp extends StatelessWidget {
  const KitNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryState()),
        ChangeNotifierProvider(create: (_) => WorkspaceState()),
      ],
      child: MaterialApp(
        title: 'KitNote',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ru', 'RU'),
          Locale('en', 'US'),
        ],
        home: const AppRootNavigator(),
      ),
    );
  }
}

class AppRootNavigator extends StatelessWidget {
  const AppRootNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceState>(context);

    // If there are active open notebook tabs, show editor; else library
    if (workspace.openNotebookIds.isNotEmpty) {
      return NotebookEditorView(
        onBackToLibrary: () {
          // Keep tabs open in background, but show library view
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
        },
      );
    }

    return LibraryScreen(
      onOpenNotebook: (id) {
        workspace.openNotebook(id);
      },
    );
  }
}
