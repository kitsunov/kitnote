import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/notebook_model.dart';
import '../../services/export_service.dart';
import '../../state/library_state.dart';

class NotebookCard extends StatelessWidget {
  final NotebookModel notebook;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onRestore;
  final String? folderName;

  const NotebookCard({
    super.key,
    required this.notebook,
    required this.onTap,
    required this.onDelete,
    this.onRestore,
    this.folderName,
  });

  void _showEditNotebookDialog(BuildContext context, LibraryState library, AppStrings strings) {
    final controller = TextEditingController(text: notebook.title);
    final tagsController = TextEditingController(text: notebook.tags.join(', '));
    int selectedCoverColor = notebook.coverColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(strings.notebookTitleLabel),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: strings.notebookTitleLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.edit_note),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma-separated)',
                    hintText: 'work, math, exam',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  strings.coverColor,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: AppColors.coverColors.map((c) {
                    final colorVal = c.toARGB32();
                    final isSelected = selectedCoverColor == colorVal;
                    return GestureDetector(
                      onTap: () => setDlgState(() => selectedCoverColor = colorVal),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black87 : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () {
                final parsedTags = tagsController.text
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toSet()
                    .toList();
                library.renameNotebook(
                  notebook.id,
                  controller.text,
                  coverColor: selectedCoverColor,
                  tags: parsedTags,
                );
                Navigator.pop(ctx);
              },
              child: Text(strings.done),
            ),
          ],
        ),
      ),
    ).then((_) {
      controller.dispose();
      tagsController.dispose();
    });
  }

  void _showMoveToFolderDialog(BuildContext context, LibraryState library, AppStrings strings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.moveToFolder),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_off_outlined, color: Colors.blueGrey),
                title: Text(strings.noFolder),
                trailing: notebook.folderId == null ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  library.moveNotebookToFolder(notebook.id, null);
                  Navigator.pop(ctx);
                },
              ),
              ...library.folders.map((f) {
                final isCurrent = notebook.folderId == f.id;
                return ListTile(
                  leading: Icon(Icons.folder, color: f.color),
                  title: Text(f.name),
                  trailing: isCurrent ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    library.moveNotebookToFolder(notebook.id, f.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context).strings;
    final locale = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', locale);
    final formattedDate = dateFormat.format(notebook.updatedAt);
    final coverColor = Color(notebook.coverColor);

    return GestureDetector(
      onTap: notebook.isDeleted
          ? () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(notebook.title),
                  content: Text('${strings.restore}?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(strings.cancel)),
                    ElevatedButton(
                      onPressed: () {
                        onRestore?.call();
                        Navigator.pop(ctx);
                      },
                      child: Text(strings.restore),
                    ),
                  ],
                ),
              );
            }
          : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notebook Cover Preview
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: coverColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Stack(
                  children: [
                    // Spine binding line effect
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: Container(color: Colors.black12),
                    ),
                    Positioned(
                      left: 18,
                      top: 0,
                      bottom: 0,
                      width: 1,
                      child: Container(color: Colors.white24),
                    ),

                    // Title on Cover
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          notebook.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                    // Pin Badge at top-left (1-tap toggle)
                    if (!notebook.isDeleted)
                      Positioned(
                        top: 8,
                        left: 24,
                        child: GestureDetector(
                          onTap: () => context.read<LibraryState>().togglePinNotebook(notebook.id),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: notebook.isPinned ? Colors.amber.shade600 : Colors.black26,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              notebook.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // PDF Badge if applicable
                    if (notebook.isPdfNotebook)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('PDF', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Card Footer Information
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notebook.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
                          itemBuilder: (context) {
                            if (notebook.isDeleted) {
                              return [
                                PopupMenuItem(
                                  value: 'restore',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.restore_from_trash, size: 18, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text(strings.restore),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'deletePermanent',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_forever, size: 18, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Text(strings.deletePermanently, style: const TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ];
                            }
                            return [
                              PopupMenuItem(
                                value: 'pin',
                                child: Row(
                                  children: [
                                    Icon(
                                      notebook.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                                      size: 18,
                                      color: Colors.amber.shade800,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(notebook.isPinned ? 'Unpin' : 'Pin'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 18, color: Colors.indigo),
                                    const SizedBox(width: 8),
                                    Text(strings.notebookTitleLabel),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'duplicate',
                                child: Row(
                                  children: [
                                    const Icon(Icons.copy_outlined, size: 18, color: Colors.deepPurple),
                                    const SizedBox(width: 8),
                                    Text(strings.duplicate),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf, size: 18, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(strings.exportPdf),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'exportBackup',
                                child: Row(
                                  children: [
                                    Icon(Icons.archive_outlined, size: 18, color: Colors.teal),
                                    SizedBox(width: 8),
                                    Text('.kitnote Backup'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'moveToFolder',
                                child: Row(
                                  children: [
                                    const Icon(Icons.drive_file_move_outlined, size: 18, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(strings.moveToFolder),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text(strings.deleteNotebook, style: const TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ];
                          },
                          onSelected: (action) async {
                            final library = context.read<LibraryState>();
                            if (action == 'restore') {
                              onRestore?.call();
                            } else if (action == 'deletePermanent') {
                              onDelete();
                            } else if (action == 'pin') {
                              library.togglePinNotebook(notebook.id);
                            } else if (action == 'rename') {
                              _showEditNotebookDialog(context, library, strings);
                            } else if (action == 'duplicate') {
                              await library.duplicateNotebook(notebook.id);
                            } else if (action == 'export') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${strings.exportPdf}...')),
                              );
                              final file = await ExportService.exportNotebookToPdf(notebook, share: true);
                              if (file != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${strings.exportPdf}: ${file.path.split('/').last}')),
                                );
                              }
                            } else if (action == 'exportBackup') {
                              final file = await library.exportNotebookBackup(notebook);
                              if (file != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Backup: ${file.path.split('/').last}')),
                                );
                              }
                            } else if (action == 'moveToFolder') {
                              _showMoveToFolderDialog(context, library, strings);
                            } else if (action == 'delete') {
                              onDelete();
                            }
                          },
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        if (folderName != null) ...[
                          Icon(Icons.folder_outlined, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              folderName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${notebook.pageCount} ${strings.page.toLowerCase()}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                        if (notebook.tags.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: notebook.tags.take(3).map((tag) {
                                  return GestureDetector(
                                    onTap: () => context.read<LibraryState>().setSearchQuery(tag),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#$tag',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
