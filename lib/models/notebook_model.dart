import 'page_model.dart';
import 'page_template_model.dart';

class NotebookModel {
  final String id;
  final String title;
  final String? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int coverColor;
  final List<PageModel> pages;
  final String? sourcePdfPath;
  final int pdfTotalPages;
  final bool isPinned;
  final List<String> tags;

  const NotebookModel({
    required this.id,
    required this.title,
    this.folderId,
    required this.createdAt,
    required this.updatedAt,
    this.coverColor = 0xFF3B82F6,
    this.pages = const [],
    this.sourcePdfPath,
    this.pdfTotalPages = 0,
    this.isPinned = false,
    this.tags = const [],
  });

  bool get isPdfNotebook => sourcePdfPath != null && sourcePdfPath!.isNotEmpty;

  int get pageCount => pages.isNotEmpty ? pages.length : (pdfTotalPages > 0 ? pdfTotalPages : 1);

  NotebookModel copyWith({
    String? id,
    String? title,
    String? folderId,
    bool clearFolderId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? coverColor,
    List<PageModel>? pages,
    String? sourcePdfPath,
    int? pdfTotalPages,
    bool? isPinned,
    List<String>? tags,
  }) {
    return NotebookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverColor: coverColor ?? this.coverColor,
      pages: pages ?? this.pages,
      sourcePdfPath: sourcePdfPath ?? this.sourcePdfPath,
      pdfTotalPages: pdfTotalPages ?? this.pdfTotalPages,
      isPinned: isPinned ?? this.isPinned,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'fId': folderId,
    'cAt': createdAt.toIso8601String(),
    'uAt': updatedAt.toIso8601String(),
    'cCol': coverColor,
    'pages': pages.map((p) => p.toJson()).toList(),
    'pdfPath': sourcePdfPath,
    'pdfCount': pdfTotalPages,
    'pinned': isPinned,
    'tags': tags,
  };

  factory NotebookModel.fromJson(Map<String, dynamic> json) => NotebookModel(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Безымянный блокнот',
    folderId: json['fId'] as String?,
    createdAt: json['cAt'] != null
        ? DateTime.tryParse(json['cAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: json['uAt'] != null
        ? DateTime.tryParse(json['uAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    coverColor: json['cCol'] as int? ?? 0xFF3B82F6,
    pages: (json['pages'] as List? ?? [])
        .map((p) => PageModel.fromJson(p as Map<String, dynamic>))
        .toList(),
    sourcePdfPath: json['pdfPath'] as String?,
    pdfTotalPages: json['pdfCount'] as int? ?? 0,
    isPinned: json['pinned'] as bool? ?? false,
    tags: (json['tags'] as List? ?? []).map((e) => e.toString()).toList(),
  );

  static NotebookModel createNew({
    required String id,
    required String title,
    String? folderId,
    int coverColor = 0xFF3B82F6,
    PaperTemplateType templateType = PaperTemplateType.narrowRuled,
    PaperColorTheme paperTheme = PaperColorTheme.ivory,
  }) {
    final now = DateTime.now();
    final firstPage = PageModel(
      id: '${id}_p0',
      pageIndex: 0,
      template: PageTemplateModel(
        type: templateType,
        colorTheme: paperTheme,
      ),
    );
    return NotebookModel(
      id: id,
      title: title,
      folderId: folderId,
      createdAt: now,
      updatedAt: now,
      coverColor: coverColor,
      pages: [firstPage],
    );
  }
}
