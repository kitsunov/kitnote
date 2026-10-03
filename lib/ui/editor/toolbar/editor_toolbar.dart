import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../engine/palm_rejection_manager.dart';
import '../../../models/page_template_model.dart';
import '../../../models/tool_type.dart';
import '../../../state/notebook_editor_state.dart';
import '../../widgets/color_circle.dart';
import '../../widgets/custom_icon_button.dart';
import 'eraser_picker_sheet.dart';
import 'highlighter_picker_sheet.dart';
import 'page_manager_sheet.dart';
import 'pen_picker_sheet.dart';

class EditorToolbar extends StatelessWidget {
  final NotebookEditorState state;
  final VoidCallback onToggleSplitScreen;
  final bool isSplitActive;

  const EditorToolbar({
    super.key,
    required this.state,
    required this.onToggleSplitScreen,
    this.isSplitActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeTool = state.activeTool;
    final strings = AppLocalizations.of(context).strings;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 1. Tool selection group
            CustomIconButton(
              icon: Icons.edit,
              tooltip: '${strings.pen} (${strings.penSettings})',
              isSelected: activeTool.isPen,
              onPressed: () {
                if (activeTool.isPen) {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => PenPickerSheet(state: state),
                  );
                } else {
                  state.setTool(ToolType.fountainPen);
                }
              },
            ),
            CustomIconButton(
              icon: Icons.border_color,
              tooltip: '${strings.highlighter} (${strings.highlighterThickness})',
              isSelected: activeTool == ToolType.highlighter,
              onPressed: () {
                if (activeTool == ToolType.highlighter) {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => HighlighterPickerSheet(state: state),
                  );
                } else {
                  state.setTool(ToolType.highlighter);
                }
              },
            ),
            CustomIconButton(
              icon: Icons.cleaning_services_outlined,
              tooltip: '${strings.strokeEraser} / ${strings.pixelEraser} (${strings.eraserSize})',
              isSelected: activeTool.isEraser,
              onPressed: () {
                if (activeTool.isEraser) {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => EraserPickerSheet(state: state),
                  );
                } else {
                  state.setTool(ToolType.strokeEraser);
                }
              },
            ),
            CustomIconButton(
              icon: Icons.gesture,
              tooltip: strings.lasso,
              isSelected: activeTool == ToolType.lasso,
              onPressed: () => state.setTool(ToolType.lasso),
            ),
            CustomIconButton(
              icon: Icons.straighten,
              tooltip: strings.ruler,
              isSelected: state.isRulerEnabled,
              onPressed: () => state.toggleRuler(),
            ),
            CustomIconButton(
              icon: Icons.title,
              tooltip: strings.text,
              isSelected: activeTool == ToolType.textBox,
              onPressed: () {
                state.setTool(ToolType.textBox);
              },
            ),
            CustomIconButton(
              icon: Icons.add_photo_alternate_outlined,
              tooltip: strings.photo,
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(type: FileType.image);
                if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
                  state.addImageElement(result.files.first.path!, const Offset(100, 150), 300, 220);
                }
              },
            ),
            CustomIconButton(
              icon: Icons.grid_on_outlined,
              tooltip: strings.changeTemplate,
              onPressed: () => _showTemplateDialog(context, state, strings),
            ),

            const VerticalDivider(indent: 12, endIndent: 12, width: 20),

            // 2. Quick Color Palette Swatches (persisted in state, scrollable, long-press to delete)
            ...state.customPaletteColors.map((cInt) {
              final c = Color(cInt);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onLongPress: () {
                    if (state.customPaletteColors.length > 1) {
                      _confirmDeleteColor(context, state, cInt, strings);
                    }
                  },
                  child: ColorCircle(
                    color: c,
                    size: 24,
                    isSelected: state.activeColor == cInt,
                    onTap: () => state.setColor(cInt),
                  ),
                ),
              );
            }),

            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.blueAccent),
              tooltip: strings.addColor,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(),
              onPressed: () => _showAddColorDialog(context, state, strings),
            ),

            // Full color picker trigger
            IconButton(
              icon: const Icon(Icons.palette_outlined, size: 20, color: Colors.blueGrey),
              tooltip: strings.colorPalette,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(strings.selectColor),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: Color(state.activeColor),
                        onColorChanged: (newColor) => state.setColor(newColor.toARGB32()),
                        pickerAreaHeightPercent: 0.7,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(strings.done),
                      ),
                    ],
                  ),
                );
              },
            ),

            const VerticalDivider(indent: 12, endIndent: 12, width: 20),

            // 3. Undo / Redo
            CustomIconButton(
              icon: Icons.undo,
              tooltip: strings.undo,
              onPressed: state.canUndo ? () => state.undo() : null,
              color: state.canUndo ? Colors.black87 : Colors.grey.shade300,
            ),
            CustomIconButton(
              icon: Icons.redo,
              tooltip: strings.redo,
              onPressed: state.canRedo ? () => state.redo() : null,
              color: state.canRedo ? Colors.black87 : Colors.grey.shade300,
            ),
            const SizedBox(width: 4),
            _buildSaveStatusIndicator(context, state, strings),

            const SizedBox(width: 16),

            // 4. Palm Rejection Status Toggle Pill
            GestureDetector(
              onTap: () => state.togglePalmRejectionMode(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: state.palmRejection.mode == PalmRejectionMode.stylusOnly
                      ? Colors.green.shade50
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: state.palmRejection.mode == PalmRejectionMode.stylusOnly
                        ? Colors.green.shade300
                        : Colors.amber.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.palmRejection.mode == PalmRejectionMode.stylusOnly
                          ? Icons.edit_attributes
                          : Icons.touch_app,
                      size: 16,
                      color: state.palmRejection.mode == PalmRejectionMode.stylusOnly
                          ? Colors.green.shade800
                          : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      state.palmRejection.mode == PalmRejectionMode.stylusOnly
                          ? strings.palmRejectionOn
                          : strings.palmRejectionOff,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: state.palmRejection.mode == PalmRejectionMode.stylusOnly
                            ? Colors.green.shade800
                            : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 5. Page Navigation Pill
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => PageManagerSheet(state: state),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: state.currentPageIndex > 0 ? () => state.previousPage() : null,
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _showJumpToPageDialog(context, state, strings),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          '${state.currentPageIndex + 1} / ${state.notebook.pages.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: state.currentPageIndex < state.notebook.pages.length - 1
                          ? () => state.nextPage()
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18, color: Colors.blue),
                      padding: const EdgeInsets.only(left: 4),
                      constraints: const BoxConstraints(),
                      tooltip: strings.addPage,
                      onPressed: () => state.addNewPage(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 6. Split Screen Toggle Button
            CustomIconButton(
              icon: Icons.vertical_split_outlined,
              tooltip: strings.splitScreen,
              isSelected: isSplitActive,
              selectedColor: Colors.purple,
              onPressed: onToggleSplitScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveStatusIndicator(
    BuildContext context,
    NotebookEditorState state,
    AppStrings strings,
  ) {
    IconData icon;
    Color color;
    String tooltip;

    switch (state.saveStatus) {
      case SaveStatus.saving:
        icon = Icons.sync;
        color = Colors.blue.shade600;
        tooltip = strings.saving;
        break;
      case SaveStatus.error:
        icon = Icons.cloud_off_outlined;
        color = Colors.red.shade600;
        tooltip = strings.saveError;
        break;
      case SaveStatus.saved:
        icon = Icons.cloud_done_outlined;
        color = Colors.grey.shade600;
        tooltip = strings.saved;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: state.saveStatus == SaveStatus.saving
              ? SizedBox(
                  key: const ValueKey('saving'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(
                  icon,
                  key: ValueKey(state.saveStatus),
                  size: 18,
                  color: color,
                ),
        ),
      ),
    );
  }

  void _showJumpToPageDialog(
    BuildContext context,
    NotebookEditorState state,
    AppStrings strings,
  ) {
    final totalPages = state.notebook.pages.length;
    final controller = TextEditingController(text: '${state.currentPageIndex + 1}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.goToPage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${strings.pageNumber} (1 - $totalPages):'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '1 - $totalPages',
              ),
              onSubmitted: (val) {
                final p = int.tryParse(val.trim());
                if (p != null && p >= 1 && p <= totalPages) {
                  state.setActivePageIndex(p - 1);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final p = int.tryParse(controller.text.trim());
              if (p != null && p >= 1 && p <= totalPages) {
                state.setActivePageIndex(p - 1);
                Navigator.pop(ctx);
              }
            },
            child: Text(strings.done),
          ),
        ],
      ),
    );
  }

  void _showAddColorDialog(
    BuildContext context,
    NotebookEditorState state,
    AppStrings strings,
  ) {
    Color pickedColor = Color(state.activeColor);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.addColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickedColor,
            onColorChanged: (c) => pickedColor = c,
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              state.addCustomColor(pickedColor.toARGB32());
              state.setColor(pickedColor.toARGB32());
              Navigator.pop(ctx);
            },
            child: Text(strings.done),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteColor(
    BuildContext context,
    NotebookEditorState state,
    int colorInt,
    AppStrings strings,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteColor),
        content: Row(
          children: [
            ColorCircle(color: Color(colorInt), size: 28, isSelected: false, onTap: () {}),
            const SizedBox(width: 12),
            Expanded(child: Text('${strings.deleteColor}?')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              state.removeCustomColor(colorInt);
              Navigator.pop(ctx);
            },
            child: Text(strings.delete),
          ),
        ],
      ),
    );
  }

  void _showTemplateDialog(
    BuildContext context,
    NotebookEditorState state,
    AppStrings strings,
  ) {
    PaperTemplateType selectedType = state.currentPage.template.type;
    PaperColorTheme selectedTheme = state.currentPage.template.colorTheme;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(strings.changeTemplate),
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
                state.updatePageTemplate(state.currentPageIndex, newTemplate);
                Navigator.pop(ctx);
              },
              child: Text(strings.applyToCurrentPage),
            ),
          ],
        ),
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
