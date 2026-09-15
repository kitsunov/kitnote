import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/notebook_model.dart';
import '../../services/export_service.dart';

class NotebookCard extends StatelessWidget {
  final NotebookModel notebook;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String? folderName;

  const NotebookCard({
    super.key,
    required this.notebook,
    required this.onTap,
    required this.onDelete,
    this.folderName,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'ru');
    final formattedDate = dateFormat.format(notebook.updatedAt);
    final coverColor = Color(notebook.coverColor);

    return GestureDetector(
      onTap: onTap,
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
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'export',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Экспорт в PDF'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Удалить тетрадь', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (action) async {
                            if (action == 'export') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Экспорт в PDF...')),
                              );
                              final file = await ExportService.exportNotebookToPdf(notebook);
                              if (file != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Сохранено: ${file.path}')),
                                );
                              }
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
                          Text(
                            folderName!,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${notebook.pageCount} стр.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
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
