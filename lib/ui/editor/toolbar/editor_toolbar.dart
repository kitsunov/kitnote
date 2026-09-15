import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../engine/palm_rejection_manager.dart';
import '../../../models/tool_type.dart';
import '../../../state/notebook_editor_state.dart';
import '../../widgets/color_circle.dart';
import '../../widgets/custom_icon_button.dart';
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
            icon: Icons.brush_outlined,
            tooltip: strings.highlighter,
            isSelected: activeTool == ToolType.highlighter,
            onPressed: () => state.setTool(ToolType.highlighter),
          ),
          CustomIconButton(
            icon: Icons.cleaning_services_outlined,
            tooltip: '${strings.strokeEraser} / ${strings.pixelEraser}',
            isSelected: activeTool.isEraser,
            onPressed: () {
              if (activeTool == ToolType.strokeEraser) {
                state.setTool(ToolType.pixelEraser);
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
              state.addTextElement('${strings.text}...', const Offset(150, 200));
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

          const VerticalDivider(indent: 12, endIndent: 12, width: 20),

          // 2. Quick Color Palette Swatches
          ...AppColors.penPresets.take(5).map((c) {
            return ColorCircle(
              color: c,
              size: 24,
              isSelected: state.activeColor == c.toARGB32(),
              onTap: () => state.setColor(c.toARGB32()),
            );
          }),

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

          const Spacer(),

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
                  Text(
                    '${state.currentPageIndex + 1} / ${state.notebook.pages.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
}
