import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../state/notebook_editor_state.dart';
import '../canvas/paper_grid_painter.dart';

class PageManagerSheet extends StatelessWidget {
  final NotebookEditorState state;

  const PageManagerSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final notebook = state.notebook;
    final pages = notebook.pages;
    final strings = AppLocalizations.of(context).strings;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${strings.page} (${pages.length})',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(strings.addPage),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                    ),
                    onPressed: () {
                      state.addNewPage();
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pages Grid
          Expanded(
            child: GridView.builder(
              itemCount: pages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final page = pages[index];
                final isCurrent = index == state.currentPageIndex;

                return GestureDetector(
                  onTap: () {
                    state.goToPage(index);
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCurrent ? Colors.blue : Colors.grey.shade300,
                              width: isCurrent ? 3 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                // Thumbnail of paper grid
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: PaperGridPainter(template: page.template),
                                  ),
                                ),
                                // Stroke count overlay
                                Positioned(
                                  bottom: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${page.strokes.length} штр.',
                                      style: const TextStyle(fontSize: 10, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${strings.page} ${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCurrent ? Colors.blue : Colors.black87,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'duplicate',
                                child: Text(strings.duplicatePage),
                              ),
                              if (pages.length > 1)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(strings.deletePage, style: const TextStyle(color: Colors.red)),
                                ),
                            ],
                            onSelected: (action) {
                              if (action == 'duplicate') {
                                state.duplicateCurrentPage();
                              } else if (action == 'delete') {
                                state.deleteCurrentPage();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
