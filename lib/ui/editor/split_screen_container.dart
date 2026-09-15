import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        final leftWidth = totalWidth * workspace.splitRatio;
        final rightWidth = totalWidth - leftWidth;

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

            // Draggable Divider Handle
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                final newRatio = (leftWidth + details.delta.dx) / totalWidth;
                workspace.setSplitRatio(newRatio);
              },
              child: Container(
                width: 10,
                color: Colors.grey.shade200,
                child: Center(
                  child: Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade500,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            // Right Notebook Viewport
            SizedBox(
              width: rightWidth - 10,
              child: ListenableBuilder(
                listenable: _secondaryEditorState!,
                builder: (context, _) {
                  return Column(
                    children: [
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
