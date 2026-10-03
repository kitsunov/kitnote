import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../../models/notebook_model.dart';
import '../../state/library_state.dart';
import '../../state/notebook_editor_state.dart';
import '../../state/workspace_state.dart';
import 'canvas/interactive_canvas.dart';
import 'toolbar/editor_toolbar.dart';

class SplitScreenContainer extends StatefulWidget {
  final NotebookModel primaryNotebook;
  final NotebookModel? secondaryNotebook;

  const SplitScreenContainer({
    super.key,
    required this.primaryNotebook,
    this.secondaryNotebook,
  });

  @override
  State<SplitScreenContainer> createState() => _SplitScreenContainerState();
}

class _SplitScreenContainerState extends State<SplitScreenContainer> {
  late NotebookEditorState _primaryEditorState;
  NotebookEditorState? _secondaryEditorState;

  @override
  void initState() {
    super.initState();
    final library = context.read<LibraryState>();
    _primaryEditorState = library.getOrCreateEditor(widget.primaryNotebook.id);
    if (widget.secondaryNotebook != null) {
      _secondaryEditorState = library.getOrCreateEditor(widget.secondaryNotebook!.id);
    }
  }

  @override
  void didUpdateWidget(covariant SplitScreenContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final library = context.read<LibraryState>();
    if (oldWidget.primaryNotebook.id != widget.primaryNotebook.id) {
      _primaryEditorState = library.getOrCreateEditor(widget.primaryNotebook.id);
    }
    if (widget.secondaryNotebook != null) {
      if (oldWidget.secondaryNotebook?.id != widget.secondaryNotebook!.id || _secondaryEditorState == null) {
        _secondaryEditorState = library.getOrCreateEditor(widget.secondaryNotebook!.id);
      }
    } else {
      _secondaryEditorState = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceState>(context);
    final library = Provider.of<LibraryState>(context);
    final strings = AppLocalizations.of(context).strings;
    final isSplit = workspace.isSplitScreen && _secondaryEditorState != null;

    if (!isSplit) {
      return ListenableBuilder(
        listenable: _primaryEditorState,
        builder: (context, _) {
          return Column(
            children: [
              EditorToolbar(
                state: _primaryEditorState,
                isSplitActive: false,
                onToggleSplitScreen: () => workspace.toggleSplitScreen(null),
              ),
              Expanded(
                child: InteractiveCanvas(editorState: _primaryEditorState),
              ),
            ],
          );
        },
      );
    }

    // Split Screen View
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const dividerWidth = 36.0;
        final availableWidth = (totalWidth - dividerWidth).clamp(0.0, double.infinity);
        final leftWidth = availableWidth * workspace.splitRatio;
        final rightWidth = availableWidth - leftWidth;

        return Row(
          children: [
            // Left Notebook Viewport
            SizedBox(
              width: leftWidth,
              child: ListenableBuilder(
                listenable: _primaryEditorState,
                builder: (context, _) {
                  return Column(
                    children: [
                      EditorToolbar(
                        state: _primaryEditorState,
                        isSplitActive: true,
                        onToggleSplitScreen: () => workspace.toggleSplitScreen(null),
                      ),
                      Expanded(
                        child: InteractiveCanvas(editorState: _primaryEditorState),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Draggable Divider Handle with 36px touch zone
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  if (availableWidth > 0) {
                    workspace.setSplitRatio(workspace.splitRatio + details.delta.dx / availableWidth);
                  }
                },
                child: Container(
                  width: dividerWidth,
                  color: Colors.grey.shade100,
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Right Notebook Viewport
            SizedBox(
              width: rightWidth,
              child: ListenableBuilder(
                listenable: _secondaryEditorState!,
                builder: (context, _) {
                  return Column(
                    children: [
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.menu_book, size: 16, color: Colors.black54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: library.notebooks.any((n) => n.id == widget.secondaryNotebook?.id)
                                      ? widget.secondaryNotebook?.id
                                      : null,
                                  hint: Text(
                                    strings.selectNotebook,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  items: library.notebooks.map((nb) {
                                    return DropdownMenuItem<String>(
                                      value: nb.id,
                                      child: Text(
                                        nb.title,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newId) {
                                    if (newId != null) {
                                      workspace.setSecondaryNotebook(newId);
                                    }
                                  },
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: strings.closeSplit,
                              onPressed: () => workspace.toggleSplitScreen(null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ),
                      EditorToolbar(
                        state: _secondaryEditorState!,
                        isSplitActive: true,
                        onToggleSplitScreen: () => workspace.toggleSplitScreen(null),
                      ),
                      Expanded(
                        child: InteractiveCanvas(editorState: _secondaryEditorState!),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
