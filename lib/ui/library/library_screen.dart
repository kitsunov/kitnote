import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/page_template_model.dart';
import '../../services/update_service.dart';
import '../../state/library_state.dart';
import '../../state/workspace_state.dart';
import 'folder_tree_view.dart';
import 'new_notebook_dialog.dart';
import 'notebook_card.dart';

class LibraryScreen extends StatefulWidget {
  final Function(String notebookId) onOpenNotebook;

  const LibraryScreen({super.key, required this.onOpenNotebook});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAppUpdates(silent: true);
    });
  }

  Future<void> _checkForAppUpdates({bool silent = false}) async {
    final update = await UpdateService.checkForUpdate();
    if (!mounted) return;

    if (update != null) {
      UpdateService.showUpdateDialog(context, update);
    } else if (!silent) {
      final strings = AppLocalizations.of(context).strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.latestVersionInstalled),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showLanguageDialog() {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currentCode = localeProvider.locale?.languageCode ?? Localizations.localeOf(context).languageCode;
    final strings = AppLocalizations.of(context).strings;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.language, color: Colors.blue),
            const SizedBox(width: 8),
            Text(strings.language),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLocalizations.supportedLocales.map((loc) {
            final isSelected = loc.languageCode == currentCode;
            return ListTile(
              title: Text(AppLocalizations.getLanguageName(loc.languageCode)),
              trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                localeProvider.setLocale(loc);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = Provider.of<LibraryState>(context);
    final strings = AppLocalizations.of(context).strings;
    final isTablet = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_stories, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              strings.appTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          // Search Field
          Container(
            width: 200,
            height: 38,
            margin: const EdgeInsets.only(right: 8),
            child: TextField(
              onChanged: (val) => library.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: strings.searchHint,
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Import PDF Button
          TextButton.icon(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
            label: Text(strings.importPdf, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () async {
              final nb = await library.importPdfNotebook();
              if (nb != null) {
                widget.onOpenNotebook(nb.id);
              }
            },
          ),
          const SizedBox(width: 8),

          // Language Switcher Button
          IconButton(
            icon: const Icon(Icons.language, color: Colors.blueGrey, size: 22),
            tooltip: strings.language,
            onPressed: _showLanguageDialog,
          ),

          // Check Updates Button
          IconButton(
            icon: const Icon(Icons.system_update_alt, color: Colors.blueGrey, size: 22),
            tooltip: strings.checkUpdates,
            onPressed: () => _checkForAppUpdates(silent: false),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isTablet ? null : const Drawer(child: SafeArea(child: FolderTreeView())),
      body: Row(
        children: [
          // Sidebar on tablet/desktop
          if (isTablet) const FolderTreeView(),

          // Main Notebooks Grid
          Expanded(
            child: library.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildNotebooksGrid(context, library, strings),
          ),
        ],
      ),
      floatingActionButton: library.isViewingTrash
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(strings.newNotebook),
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => NewNotebookDialog(
                    folders: library.folders,
                    initialFolderId: library.selectedFolderId,
                    onCreated: ({
                      required String title,
                      String? folderId,
                      required int coverColor,
                      required PaperTemplateType templateType,
                      required PaperColorTheme paperTheme,
                    }) async {
                      final notebook = await library.createNotebook(
                        title: title,
                        folderId: folderId,
                        coverColor: coverColor,
                        templateType: templateType,
                        paperTheme: paperTheme,
                      );
                      widget.onOpenNotebook(notebook.id);
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNotebooksGrid(BuildContext context, LibraryState library, AppStrings strings) {
    final notebooks = library.filteredNotebooks;

    return Column(
      children: [
        if (library.isViewingTrash)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red.shade700, size: 22),
                const SizedBox(width: 10),
                Text(
                  '${strings.trash} (${notebooks.length})',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade900),
                ),
                const Spacer(),
                if (notebooks.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: Text(strings.emptyTrash),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _confirmEmptyTrash(context, library, strings),
                  ),
              ],
            ),
          ),
        Expanded(
          child: notebooks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        library.isViewingTrash ? Icons.delete_outline : Icons.menu_book,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        library.isViewingTrash ? strings.trash : strings.noNotebooks,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        library.isViewingTrash ? '' : strings.noNotebooksSubtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: notebooks.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final notebook = notebooks[index];
                    final folder = notebook.folderId != null
                        ? library.folders.firstWhere((f) => f.id == notebook.folderId, orElse: () => library.folders.first)
                        : null;

                    return NotebookCard(
                      notebook: notebook,
                      folderName: folder?.name,
                      onTap: () => widget.onOpenNotebook(notebook.id),
                      onRestore: () {
                        library.restoreFromTrash(notebook.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(strings.restoredFromTrash)),
                        );
                      },
                      onDelete: () {
                        if (library.isViewingTrash) {
                          _confirmDeletePermanently(context, library, notebook.id, strings);
                        } else {
                          context.read<WorkspaceState>().closeNotebook(notebook.id);
                          library.moveToTrash(notebook.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(strings.movedToTrash)),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmEmptyTrash(BuildContext context, LibraryState library, AppStrings strings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.emptyTrash),
        content: Text('${strings.emptyTrash}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              library.emptyTrash();
              Navigator.pop(ctx);
            },
            child: Text(strings.deletePermanently),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePermanently(BuildContext context, LibraryState library, String notebookId, AppStrings strings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deletePermanently),
        content: Text('${strings.deletePermanently}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              library.deleteNotebookPermanently(notebookId);
              Navigator.pop(ctx);
            },
            child: Text(strings.deletePermanently),
          ),
        ],
      ),
    );
  }
}
