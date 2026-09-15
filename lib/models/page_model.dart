import 'image_element_model.dart';
import 'page_template_model.dart';
import 'stroke_model.dart';
import 'text_element_model.dart';

class PageModel {
  final String id;
  final int pageIndex;
  final PageTemplateModel template;
  final List<StrokeModel> strokes;
  final List<TextElementModel> textElements;
  final List<ImageElementModel> imageElements;
  final int? pdfPageIndex;
  final double width;
  final double height;

  const PageModel({
    required this.id,
    required this.pageIndex,
    this.template = const PageTemplateModel(),
    this.strokes = const [],
    this.textElements = const [],
    this.imageElements = const [],
    this.pdfPageIndex,
    this.width = 1200.0,
    this.height = 1600.0,
  });

  bool get isPdfPage => pdfPageIndex != null;

  PageModel copyWith({
    String? id,
    int? pageIndex,
    PageTemplateModel? template,
    List<StrokeModel>? strokes,
    List<TextElementModel>? textElements,
    List<ImageElementModel>? imageElements,
    int? pdfPageIndex,
    double? width,
    double? height,
  }) {
    return PageModel(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      template: template ?? this.template,
      strokes: strokes ?? this.strokes,
      textElements: textElements ?? this.textElements,
      imageElements: imageElements ?? this.imageElements,
      pdfPageIndex: pdfPageIndex ?? this.pdfPageIndex,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'idx': pageIndex,
    'tpl': template.toJson(),
    'stk': strokes.map((s) => s.toJson()).toList(),
    'txt': textElements.map((t) => t.toJson()).toList(),
    'img': imageElements.map((i) => i.toJson()).toList(),
    'pdfIdx': pdfPageIndex,
    'w': width,
    'h': height,
  };

  factory PageModel.fromJson(Map<String, dynamic> json) => PageModel(
    id: json['id'] as String,
    pageIndex: json['idx'] as int? ?? 0,
    template: json['tpl'] != null
        ? PageTemplateModel.fromJson(json['tpl'] as Map<String, dynamic>)
        : const PageTemplateModel(),
    strokes: (json['stk'] as List? ?? [])
        .map((s) => StrokeModel.fromJson(s as Map<String, dynamic>))
        .toList(),
    textElements: (json['txt'] as List? ?? [])
        .map((t) => TextElementModel.fromJson(t as Map<String, dynamic>))
        .toList(),
    imageElements: (json['img'] as List? ?? [])
        .map((i) => ImageElementModel.fromJson(i as Map<String, dynamic>))
        .toList(),
    pdfPageIndex: json['pdfIdx'] as int?,
    width: (json['w'] as num?)?.toDouble() ?? 1200.0,
    height: (json['h'] as num?)?.toDouble() ?? 1600.0,
  );
}
