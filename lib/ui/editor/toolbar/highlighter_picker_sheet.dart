import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../models/tool_type.dart';
import '../../../state/notebook_editor_state.dart';

class HighlighterPickerSheet extends StatelessWidget {
  final NotebookEditorState state;

  const HighlighterPickerSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context).strings;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final currentWidth = state.highlighterWidth;

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
                    strings.highlighterThickness,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Preset sizes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [12.0, 20.0, 32.0, 48.0].map((w) {
                  final isSelected = (currentWidth - w).abs() < 1.0;
                  return ChoiceChip(
                    label: Text('${w.toInt()} pt'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        state.setTool(ToolType.highlighter);
                        state.setHighlighterWidth(w);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Width Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(strings.strokeThickness, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                  Text('${currentWidth.toStringAsFixed(1)} pt', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: currentWidth.clamp(8.0, 64.0),
                min: 8.0,
                max: 64.0,
                divisions: 28,
                onChanged: (val) {
                  state.setTool(ToolType.highlighter);
                  state.setHighlighterWidth(val);
                },
              ),
              const SizedBox(height: 8),
              // Visual preview bar
              Center(
                child: Container(
                  width: 200,
                  height: currentWidth,
                  decoration: BoxDecoration(
                    color: Color(state.activeColor).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
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
