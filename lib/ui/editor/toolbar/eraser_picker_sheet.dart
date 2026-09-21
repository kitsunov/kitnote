import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../models/tool_type.dart';
import '../../../state/notebook_editor_state.dart';

class EraserPickerSheet extends StatelessWidget {
  final NotebookEditorState state;

  const EraserPickerSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context).strings;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final currentRadius = state.eraserRadius;
        final isStrokeEraser = state.activeTool == ToolType.strokeEraser;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.eraserSize,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Eraser Mode Toggle (Stroke Eraser vs Pixel Eraser)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        state.setTool(ToolType.strokeEraser);
                      },
                      icon: const Icon(Icons.auto_fix_normal, size: 18),
                      label: Text(strings.strokeEraser),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isStrokeEraser ? Colors.blue.shade50 : Colors.transparent,
                        side: BorderSide(
                          color: isStrokeEraser ? Colors.blue : Colors.grey.shade300,
                          width: isStrokeEraser ? 2 : 1,
                        ),
                        foregroundColor: isStrokeEraser ? Colors.blue.shade800 : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        state.setTool(ToolType.pixelEraser);
                      },
                      icon: const Icon(Icons.crop_square, size: 18),
                      label: Text(strings.pixelEraser),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !isStrokeEraser ? Colors.blue.shade50 : Colors.transparent,
                        side: BorderSide(
                          color: !isStrokeEraser ? Colors.blue : Colors.grey.shade300,
                          width: !isStrokeEraser ? 2 : 1,
                        ),
                        foregroundColor: !isStrokeEraser ? Colors.blue.shade800 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Preset sizes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [8.0, 16.0, 28.0, 44.0].map((r) {
                  final isSelected = (currentRadius - r).abs() < 1.0;
                  return ChoiceChip(
                    label: Text('${r.toInt()} px'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) state.setEraserRadius(r);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Radius Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(strings.eraserSize, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                  Text('${currentRadius.toInt()} px', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: currentRadius.clamp(4.0, 60.0),
                min: 4.0,
                max: 60.0,
                divisions: 28,
                onChanged: (val) {
                  state.setEraserRadius(val);
                },
              ),
              const SizedBox(height: 8),
              // Visual circle preview of eraser size
              Center(
                child: Container(
                  width: currentRadius * 2,
                  height: currentRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    color: Colors.blue.withValues(alpha: 0.1),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
