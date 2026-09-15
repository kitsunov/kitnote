import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../models/notebook_model.dart';
import '../../state/library_state.dart';
import '../../state/workspace_state.dart';
import 'multi_tab_bar.dart';
import 'split_screen_container.dart';

class NotebookEditorView extends StatelessWidget {
  final VoidCallback onBackToLibrary;

  const NotebookEditorView({super.key, required this.onBackToLibrary});

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceState>(context);
    final library = Provider.of<LibraryState>(context);
    final strings = AppLocalizations.of(context).strings;

    final primaryId = workspace.primaryNotebookId;
    if (primaryId == null) {
      return Scaffold(
        body: Center(child: Text(strings.noNotebooks)),
      );
    }

    final primaryNotebook = library.notebooks.where((n) => n.id == primaryId).firstOrNull;
    if (primaryNotebook == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        workspace.closeNotebook(primaryId);
      });
      return Scaffold(
        body: Center(child: Text(strings.noNotebooks)),
      );
    }

    NotebookModel? secondaryNotebook;
    if (workspace.isSplitScreen && workspace.secondaryNotebookId != null) {
      secondaryNotebook = library.notebooks.where(
        (n) => n.id == workspace.secondaryNotebookId,
      ).firstOrNull ?? primaryNotebook;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top browser-like multi-tab bar
            MultiTabBar(onBackToLibrary: onBackToLibrary),

            // Split-screen or single notebook container
            Expanded(
              child: SplitScreenContainer(
                primaryNotebook: primaryNotebook,
                secondaryNotebook: secondaryNotebook,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
