import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/page_template_model.dart';
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
                        state.goToPage(index);
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
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CustomPaint(
                                        painter: PaperGridPainter(template: page.template),
                                      ),
                                    ),
                                  ),
                                  if (page.isBookmarked)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                                          ],
                                        ),
                                        child: const Icon(Icons.bookmark, color: Colors.amber, size: 16),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Page Info & Options Menu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${strings.page} ${index + 1}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrent ? Colors.blue : Colors.black87,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'bookmark',
                                    child: Row(
                                      children: [
                                        Icon(
                                          page.isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                                          size: 18,
                                          color: Colors.amber.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(strings.bookmark),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'insertAfter',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.post_add, size: 18, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text(strings.insertPageAfter),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'duplicate',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.copy, size: 18, color: Colors.blueGrey),
                                        const SizedBox(width: 8),
                                        Text(strings.duplicatePage),
                                      ],
                                    ),
                                  ),
                                  if (index > 0)
                                    PopupMenuItem(
                                      value: 'moveLeft',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.arrow_back, size: 18, color: Colors.blueGrey),
                                          const SizedBox(width: 8),
                                          Text(strings.movePageLeft),
                                        ],
                                      ),
                                    ),
                                  if (index < pages.length - 1)
                                    PopupMenuItem(
                                      value: 'moveRight',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.arrow_forward, size: 18, color: Colors.blueGrey),
                                          const SizedBox(width: 8),
                                          Text(strings.movePageRight),
                                        ],
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 'template',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.grid_on, size: 18, color: Colors.indigo),
                                        const SizedBox(width: 8),
                                        Text(strings.changeTemplate),
                                      ],
                                    ),
                                  ),
                                  if (pages.length > 1)
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Text(strings.deletePage, style: const TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                ],
                                onSelected: (action) {
                                  if (action == 'bookmark') {
                                    state.togglePageBookmark(index);
                                  } else if (action == 'insertAfter') {
                                    state.insertPageAfter(index);
                                  } else if (action == 'duplicate') {
                                    state.duplicatePageAt(index);
                                  } else if (action == 'moveLeft') {
                                    state.movePage(index, index - 1);
                                  } else if (action == 'moveRight') {
                                    state.movePage(index, index + 1);
                                  } else if (action == 'template') {
                                    _showPageTemplateDialog(context, state, index, strings);
                                  } else if (action == 'delete') {
                                    _confirmDeletePage(context, state, index, strings);
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

  void _showPageTemplateDialog(
    BuildContext context,
    NotebookEditorState state,
    int pageIndex,
    AppStrings strings,
  ) {
    final page = state.notebook.pages[pageIndex];
    PaperTemplateType selectedType = page.template.type;
    PaperColorTheme selectedTheme = page.template.colorTheme;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('${strings.changeTemplate} (${strings.page} ${pageIndex + 1})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.paperTemplate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PaperTemplateType.values.map((t) {
                    final isSelected = t == selectedType;
                    return ChoiceChip(
                      label: Text(_getTemplateTypeName(t, strings)),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setDlgState(() => selectedType = t);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(strings.paperColor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PaperColorTheme.values.map((c) {
                    final isSelected = c == selectedTheme;
                    return ChoiceChip(
                      label: Text(_getPaperThemeName(c, strings)),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setDlgState(() => selectedTheme = c);
                      },
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
            OutlinedButton(
              onPressed: () {
                final newTemplate = PageTemplateModel(type: selectedType, colorTheme: selectedTheme);
                state.updateNotebookTemplate(newTemplate);
                Navigator.pop(ctx);
              },
              child: Text(strings.applyToAllPages),
            ),
            FilledButton(
              onPressed: () {
                final newTemplate = PageTemplateModel(type: selectedType, colorTheme: selectedTheme);
                state.updatePageTemplate(pageIndex, newTemplate);
                Navigator.pop(ctx);
              },
              child: Text(strings.applyToCurrentPage),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePage(
    BuildContext context,
    NotebookEditorState state,
    int pageIndex,
    AppStrings strings,
  ) {
    if (state.notebook.pages.length <= 1) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deletePage),
        content: Text('${strings.deletePage} ${pageIndex + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              state.deletePageAt(pageIndex);
              Navigator.pop(ctx);
            },
            child: Text(strings.deletePage),
          ),
        ],
      ),
    );
  }

  String _getTemplateTypeName(PaperTemplateType type, AppStrings strings) {
    switch (type) {
      case PaperTemplateType.blank:
        return strings.tplBlank;
      case PaperTemplateType.narrowRuled:
        return strings.tplNarrowRuled;
      case PaperTemplateType.wideRuled:
        return strings.tplWideRuled;
      case PaperTemplateType.gridSmall:
        return strings.tplGridSmall;
      case PaperTemplateType.gridLarge:
        return strings.tplGridLarge;
      case PaperTemplateType.dotGrid:
        return strings.tplDotGrid;
      case PaperTemplateType.cornell:
        return strings.tplCornell;
      case PaperTemplateType.weeklyPlanner:
        return strings.tplWeeklyPlanner;
      case PaperTemplateType.musicSheet:
        return strings.tplMusicSheet;
    }
  }

  String _getPaperThemeName(PaperColorTheme theme, AppStrings strings) {
    switch (theme) {
      case PaperColorTheme.white:
        return strings.colWhite;
      case PaperColorTheme.ivory:
        return strings.colIvory;
      case PaperColorTheme.dark:
        return strings.colDark;
      case PaperColorTheme.sepia:
        return strings.colSepia;
      case PaperColorTheme.softSage:
        return strings.colMint;
    }
  }
}
