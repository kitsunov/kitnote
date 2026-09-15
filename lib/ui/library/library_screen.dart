import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/page_template_model.dart';
import '../../services/google_drive_service.dart';
import '../../services/update_service.dart';
import '../../state/library_state.dart';
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
    // Check for updates silently on app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAppUpdates(silent: true);
    });
  }

  Future<void> _checkForAppUpdates({bool silent = false}) async {
    final update = await UpdateService().checkForUpdates();
    if (!mounted) return;

    if (update != null) {
      UpdateService.showUpdateDialog(context, update);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У вас установлена последняя версия KitNote (v1.0.0)'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = Provider.of<LibraryState>(context);
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
            const Text(
              'KitNote',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5),
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
                hintText: 'Поиск конспектов...',
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
            label: const Text('Импорт PDF', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
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

          // Google Drive Sync Button
          Consumer<LibraryState>(
            builder: (context, lib, _) {
              final drive = lib.googleDrive;
              final isConnected = drive.isSignedIn;
              final isSyncing = drive.status == SyncStatus.syncing;

              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: OutlinedButton.icon(
                  icon: isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.cloud_sync,
                          size: 18,
                          color: isConnected ? Colors.green.shade600 : Colors.blue.shade600,
                        ),
                  label: Text(
                    isConnected
                        ? (isSyncing ? 'Синхронизация...' : 'Google Drive')
                        : 'Войти в аккаунт',
                    style: TextStyle(
                      fontSize: 12,
                      color: isConnected ? Colors.green.shade800 : Colors.blue.shade800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: BorderSide(
                      color: isConnected ? Colors.green.shade200 : Colors.blue.shade200,
                    ),
                  ),
                  onPressed: () async {
                    if (!isConnected) {
                      final success = await drive.signIn();
                      if (success) {
                        lib.triggerSync();
                      }
                    } else {
                      lib.triggerSync();
                    }
                  },
                ),
              );
            },
          ),

          // Check Updates Button
          IconButton(
            icon: const Icon(Icons.system_update_alt, color: Colors.blueGrey, size: 22),
            tooltip: 'Проверить обновления',
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
                : _buildNotebooksGrid(context, library),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Новая тетрадь'),
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

  Widget _buildNotebooksGrid(BuildContext context, LibraryState library) {
    final notebooks = library.filteredNotebooks;

    if (notebooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Нет созданных блокнотов',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте блокнот с любой разметкой или импортируйте большой PDF',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
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
          onDelete: () => library.deleteNotebook(notebook.id),
        );
      },
    );
  }
}
