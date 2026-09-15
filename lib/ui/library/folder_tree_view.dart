import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../state/library_state.dart';

class FolderTreeView extends StatelessWidget {
  const FolderTreeView({super.key});

  @override
  Widget build(BuildContext context) {
    final library = Provider.of<LibraryState>(context);
    final strings = AppLocalizations.of(context).strings;
    final selectedFolderId = library.selectedFolderId;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strings.folders,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20, color: Colors.blue),
                  tooltip: strings.newFolder,
                  onPressed: () => _showCreateFolderDialog(context, library),
                ),
              ],
            ),
          ),

          // "All Notebooks" item
          _FolderListItem(
            title: strings.allNotebooks,
            count: library.notebooks.length,
            icon: Icons.auto_stories,
            color: Colors.blue,
            isSelected: selectedFolderId == null,
            onTap: () => library.selectFolder(null),
          ),

          const Divider(height: 16, indent: 16, endIndent: 16),

          // Folders List
          Expanded(
            child: ListView.builder(
              itemCount: library.folders.length,
              itemBuilder: (context, index) {
                final folder = library.folders[index];
                final count = library.notebooks.where((n) => n.folderId == folder.id).length;
                final isSelected = selectedFolderId == folder.id;

                return _FolderListItem(
                  title: folder.name,
                  count: count,
                  icon: Icons.folder,
                  color: folder.color,
                  isSelected: isSelected,
                  onTap: () => library.selectFolder(folder.id),
                  onDelete: () => library.deleteFolder(folder.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, LibraryState library) {
    final textController = TextEditingController();
    final strings = AppLocalizations.of(context).strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.newFolder),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: strings.folderNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                library.createFolder(name);
              }
              Navigator.pop(ctx);
            },
            child: Text(strings.create),
          ),
        ],
      ),
    );
  }
}

class _FolderListItem extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _FolderListItem({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icon, color: isSelected ? Colors.blue : color, size: 20),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.blue.shade900 : Colors.black87,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 11, color: isSelected ? Colors.blue.shade900 : Colors.black54),
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                onPressed: onDelete,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
