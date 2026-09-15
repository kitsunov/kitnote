import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../state/notebook_editor_state.dart';
import '../canvas/paper_grid_painter.dart';

class PageManagerSheet extends StatelessWidget {
  final NotebookEditorState state;

  const PageManagerSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context).strings;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final notebook = state.notebook;
        final pages = notebook.pages;

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

                    return InkWell(
                      onTap: () {
                        state.setActivePageIndex(index);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Page Thumbnail Preview
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: page.template.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrent ? Colors.blue : Colors.grey.shade300,
                                  width: isCurrent ? 2.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isCurrent
                                        ? Colors.blue.withValues(alpha: 0.2)
                                        : Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CustomPaint(
                                  painter: PaperGridPainter(template: page.template),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Page Info & Options Menu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    state.duplicatePageAt(index);
                                  } else if (action == 'delete') {
                                    state.deletePageAt(index);
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
      },
    );
  }
}
