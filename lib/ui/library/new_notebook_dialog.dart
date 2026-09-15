import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
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
  final TextEditingController _titleController = TextEditingController(text: 'Новый блокнот');
  late String? _selectedFolderId;
  int _selectedCoverColor = AppColors.coverColors.first.toARGB32();
  PaperTemplateType _selectedTemplate = PaperTemplateType.narrowRuled;
  PaperColorTheme _selectedPaperTheme = PaperColorTheme.ivory;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.initialFolderId;
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Создать блокнот',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Title input
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Название тетради',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
              const SizedBox(height: 16),

              // Folder selection
              if (widget.folders.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _selectedFolderId,
                  decoration: const InputDecoration(
                    labelText: 'Папка',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Без папки (Главная)')),
                    ...widget.folders.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedFolderId = val),
                ),
                const SizedBox(height: 16),
              ],

              // Cover Color Picker
              const Text('Цвет обложки', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
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
              const Text('Шаблон разметки страниц', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TemplateChip(
                    label: 'В линейку (узкая)',
                    icon: Icons.notes,
                    isSelected: _selectedTemplate == PaperTemplateType.narrowRuled,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.narrowRuled),
                  ),
                  _TemplateChip(
                    label: 'В клетку (5мм)',
                    icon: Icons.grid_on,
                    isSelected: _selectedTemplate == PaperTemplateType.gridSmall,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.gridSmall),
                  ),
                  _TemplateChip(
                    label: 'В точку (Bullet)',
                    icon: Icons.grain,
                    isSelected: _selectedTemplate == PaperTemplateType.dotGrid,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.dotGrid),
                  ),
                  _TemplateChip(
                    label: 'Корнелл (Конспекты)',
                    icon: Icons.view_agenda_outlined,
                    isSelected: _selectedTemplate == PaperTemplateType.cornell,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.cornell),
                  ),
                  _TemplateChip(
                    label: 'Чистый лист',
                    icon: Icons.crop_portrait,
                    isSelected: _selectedTemplate == PaperTemplateType.blank,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.blank),
                  ),
                  _TemplateChip(
                    label: 'Недельный планер',
                    icon: Icons.calendar_view_week,
                    isSelected: _selectedTemplate == PaperTemplateType.weeklyPlanner,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.weeklyPlanner),
                  ),
                  _TemplateChip(
                    label: 'Нотный стан',
                    icon: Icons.music_note,
                    isSelected: _selectedTemplate == PaperTemplateType.musicSheet,
                    onTap: () => setState(() => _selectedTemplate = PaperTemplateType.musicSheet),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Paper Color Theme Picker
              const Text('Цвет бумаги', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PaperColorOption(
                    label: 'Белая',
                    color: const Color(0xFFFFFFFF),
                    isSelected: _selectedPaperTheme == PaperColorTheme.white,
                    onTap: () => setState(() => _selectedPaperTheme = PaperColorTheme.white),
                  ),
                  _PaperColorOption(
                    label: 'Кремовая',
                    color: const Color(0xFFFAF7EE),
                    isSelected: _selectedPaperTheme == PaperColorTheme.ivory,
                    onTap: () => setState(() => _selectedPaperTheme = PaperColorTheme.ivory),
                  ),
                  _PaperColorOption(
                    label: 'Сепия',
                    color: const Color(0xFFF4ECE1),
                    isSelected: _selectedPaperTheme == PaperColorTheme.sepia,
                    onTap: () => setState(() => _selectedPaperTheme = PaperColorTheme.sepia),
                  ),
                  _PaperColorOption(
                    label: 'Мята',
                    color: const Color(0xFFEFF4F0),
                    isSelected: _selectedPaperTheme == PaperColorTheme.softSage,
                    onTap: () => setState(() => _selectedPaperTheme = PaperColorTheme.softSage),
                  ),
                  _PaperColorOption(
                    label: 'Темная',
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
                    child: const Text('Отмена'),
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
                    child: const Text('Создать'),
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
