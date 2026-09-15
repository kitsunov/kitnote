import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../state/library_state.dart';
import '../../state/workspace_state.dart';

class MultiTabBar extends StatelessWidget {
  final VoidCallback onBackToLibrary;

  const MultiTabBar({super.key, required this.onBackToLibrary});

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceState>(context);
    final library = Provider.of<LibraryState>(context);
    final strings = AppLocalizations.of(context).strings;
    final openIds = workspace.openNotebookIds;

    return Container(
      height: 42,
      color: const Color(0xFFF1F5F9),
      child: Row(
        children: [
          // Back to Library button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
            tooltip: strings.allNotebooks,
            onPressed: onBackToLibrary,
          ),

          // Scrollable Browser Tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: openIds.length,
              itemBuilder: (context, index) {
                final id = openIds[index];
                final notebook = library.notebooks.firstWhere(
                  (n) => n.id == id,
                  orElse: () => library.notebooks.first,
                );
                final isActive = index == workspace.activeTabIndex;
                final isSecondary = workspace.isSplitScreen && workspace.secondaryNotebookId == id;

                return GestureDetector(
                  onTap: () => workspace.switchTab(index),
                  child: Container(
                    margin: const EdgeInsets.only(top: 4, right: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : (isSecondary ? Colors.blue.shade50 : const Color(0xFFE2E8F0)),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      border: Border(
                        top: BorderSide(
                          color: isActive ? Colors.blue : (isSecondary ? Colors.purple : Colors.transparent),
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // PDF icon or Notebook icon
                        Icon(
                          notebook.isPdfNotebook ? Icons.picture_as_pdf : Icons.book_outlined,
                          size: 15,
                          color: notebook.isPdfNotebook ? Colors.red.shade600 : Color(notebook.coverColor),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            notebook.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive || isSecondary ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? Colors.black87 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        if (isSecondary) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Split', style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        const SizedBox(width: 8),
                        // Close tab
                        GestureDetector(
                          onTap: () => workspace.closeTab(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
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
