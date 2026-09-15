import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../models/tool_type.dart';
import '../../../state/notebook_editor_state.dart';

class PenPickerSheet extends StatelessWidget {
  final NotebookEditorState state;

  const PenPickerSheet({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context).strings;

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
                strings.penSettings,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(strings.penType, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            children: [
              _PenTypeCard(
                title: strings.ballpointPen,
                subtitle: strings.penBallpointDesc,
                icon: Icons.edit,
                isSelected: state.activeTool == ToolType.ballpointPen,
                onTap: () {
                  state.setTool(ToolType.ballpointPen);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 12),
              _PenTypeCard(
                title: strings.fountainPen,
                subtitle: strings.penFountainDesc,
                icon: Icons.gesture,
                isSelected: state.activeTool == ToolType.fountainPen,
                onTap: () {
                  state.setTool(ToolType.fountainPen);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 12),
              _PenTypeCard(
                title: strings.brushPen,
                subtitle: strings.penBrushDesc,
                icon: Icons.brush,
                isSelected: state.activeTool == ToolType.brushPen,
                onTap: () {
                  state.setTool(ToolType.brushPen);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(strings.strokeThickness, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
              Text('${state.activeStrokeWidth.toStringAsFixed(1)} pt', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: state.activeStrokeWidth,
            min: 0.5,
            max: 18.0,
            divisions: 35,
            onChanged: (val) {
              state.setStrokeWidth(val);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PenTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PenTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? theme.colorScheme.primary : Colors.grey.shade700, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? theme.colorScheme.primary : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
