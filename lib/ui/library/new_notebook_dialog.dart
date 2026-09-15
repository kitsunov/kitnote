import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_localizations.dart';
import '../../models/folder_model.dart';
import '../../models/page_template_model.dart';

class NewNotebookDialog extends StatefulWidget {
  final List<FolderModel> folders;
  final String? initialFolderId;
  final Function({
    required String title,
    String? folderId,
    required int coverColor,
    required PaperTemplateType templateType,
    required PaperColorTheme paperTheme,
  }) onCreated;

  const NewNotebookDialog({
    super.key,
    required this.folders,
    this.initialFolderId,
    required this.onCreated,
  });

  @override
  State<NewNotebookDialog> createState() => _NewNotebookDialogState();
}

class _NewNotebookDialogState extends State<NewNotebookDialog> {
  late final TextEditingController _titleController;
  late String? _selectedFolderId;
  int _selectedCoverColor = AppColors.coverColors.first.toARGB32();
  PaperTemplateType _selectedTemplate = PaperTemplateType.narrowRuled;
  PaperColorTheme _selectedPaperTheme = PaperColorTheme.ivory;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _selectedFolderId = widget.initialFolderId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_titleController.text.isEmpty) {
      _titleController.text = AppLocalizations.of(context).strings.newNotebook;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context).strings;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.createNotebookTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Title input
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: strings.notebookTitleLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.edit_note),
                ),
              ),
              const SizedBox(height: 16),

              // Folder selection
              if (widget.folders.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedFolderId,
                  decoration: InputDecoration(
                    labelText: strings.folderLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.folder_outlined),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(strings.noFolderRoot)),
                    ...widget.folders.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedFolderId = val),
                ),
                const SizedBox(height: 16),
              ],

              // Cover Color Picker
              Text(strings.coverColor, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 8),
              Row(
                children: AppColors.coverColors.map((col) {
                  final isSelected = col.toARGB32() == _selectedCoverColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCoverColor = col.toARGB32()),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black87 : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Paper Template Picker
              Text(strings.paperTemplate, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TemplateChip(
                    label: strings.tplNarrowRuled,
                    icon: Icons.notes,
                    isSelected: _selectedTemplate == PaperTemplateType.narrowRuled,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.narrowRuled),
                  ),
                  _TemplateChip(
                    label: strings.tplWideRuled,
                    icon: Icons.notes,
                    isSelected: _selectedTemplate == PaperTemplateType.wideRuled,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.wideRuled),
                  ),
                  _TemplateChip(
                    label: strings.tplGridSmall,
                    icon: Icons.grid_on,
                    isSelected: _selectedTemplate == PaperTemplateType.gridSmall,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.gridSmall),
                  ),
                  _TemplateChip(
                    label: strings.tplGridLarge,
                    icon: Icons.grid_on,
                    isSelected: _selectedTemplate == PaperTemplateType.gridLarge,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.gridLarge),
                  ),
                  _TemplateChip(
                    label: strings.tplDotGrid,
                    icon: Icons.grain,
                    isSelected: _selectedTemplate == PaperTemplateType.dotGrid,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.dotGrid),
                  ),
                  _TemplateChip(
                    label: strings.tplCornell,
                    icon: Icons.view_agenda_outlined,
                    isSelected: _selectedTemplate == PaperTemplateType.cornell,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.cornell),
                  ),
                  _TemplateChip(
                    label: strings.tplBlank,
                    icon: Icons.crop_portrait,
                    isSelected: _selectedTemplate == PaperTemplateType.blank,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.blank),
                  ),
                  _TemplateChip(
                    label: strings.tplWeeklyPlanner,
                    icon: Icons.calendar_view_week,
                    isSelected: _selectedTemplate == PaperTemplateType.weeklyPlanner,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.weeklyPlanner),
                  ),
                  _TemplateChip(
                    label: strings.tplMusicSheet,
                    icon: Icons.music_note,
                    isSelected: _selectedTemplate == PaperTemplateType.musicSheet,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.musicSheet),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Paper Color Theme Picker
              Text(strings.paperColor, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PaperColorOption(
                    label: strings.colWhite,
                    color: const Color(0xFFFFFFFF),
                    isSelected: _selectedPaperTheme == PaperColorTheme.white,
                    onTap: () => setState(() => _selectedPaperTheme = PaperColorTheme.white),
                  ),
                  _PaperColorOption(
                    label: strings.colIvory,
                    color: const Color(0xFFFAF7EE),
                    isSelected: _selectedPaperTheme == PaperColorTheme.ivory,
                    onTap: () => setState(() => _selectedPaperTheme = PaperColorTheme.ivory),
                  ),
                  _PaperColorOption(
                    label: strings.colSepia,
                    color: const Color(0xFFF4ECE1),
                    isSelected: _selectedPaperTheme == PaperColorTheme.sepia,
                    onTap: () => setState(() => _selectedPaperTheme = PaperColorTheme.sepia),
                  ),
                  _PaperColorOption(
                    label: strings.colMint,
                    color: const Color(0xFFEFF4F0),
                    isSelected: _selectedPaperTheme == PaperColorTheme.softSage,
                    onTap: () => setState(() => _selectedPaperTheme = PaperColorTheme.softSage),
                  ),
                  _PaperColorOption(
                    label: strings.colDark,
                    color: const Color(0xFF181A20),
                    isSelected: _selectedPaperTheme == PaperColorTheme.dark,
                    onTap: () => setState(() => _selectedPaperTheme = PaperColorTheme.dark),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(strings.cancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      final title = _titleController.text.trim();
                      if (title.isNotEmpty) {
                        widget.onCreated(
                          title: title,
                          folderId: _selectedFolderId,
                          coverColor: _selectedCoverColor,
                          templateType: _selectedTemplate,
                          paperTheme: _selectedPaperTheme,
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: Text(strings.create),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.black54),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.blue,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _PaperColorOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaperColorOption({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade400,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: color == const Color(0xFF181A20) ? Colors.white : Colors.blue,
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
