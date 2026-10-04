import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../engine/pdf_virtual_cache.dart';
import '../../../models/image_element_model.dart';
import '../../../models/page_model.dart';
import '../../../models/point_model.dart';
import '../../../models/text_element_model.dart';
import '../../../models/tool_type.dart';
import '../../../state/notebook_editor_state.dart';
import 'canvas_painter.dart';
import 'paper_grid_painter.dart';
import 'ruler_overlay.dart';

class InteractiveCanvas extends StatefulWidget {
  final NotebookEditorState editorState;

  const InteractiveCanvas({super.key, required this.editorState});

  @override
  State<InteractiveCanvas> createState() => _InteractiveCanvasState();
}

class _InteractiveCanvasState extends State<InteractiveCanvas> {
  final TransformationController _transformController = TransformationController();
  bool _isDrawingWithStylus = false;
  int? _drawingPageIndex;
  int? _activeDrawingPointerId;
  double _viewportHeight = 800.0;
  int _visibleStartPage = 0;
  int _visibleEndPage = 5;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
    widget.editorState.addListener(_onEditorStateChanged);
  }

  @override
  void didUpdateWidget(InteractiveCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorState != widget.editorState) {
      oldWidget.editorState.removeListener(_onEditorStateChanged);
      widget.editorState.addListener(_onEditorStateChanged);
    }
  }

  @override
  void dispose() {
    widget.editorState.removeListener(_onEditorStateChanged);
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onEditorStateChanged() {
    if (!mounted) return;
    final targetPage = widget.editorState.scrollTargetPageIndex;
    if (targetPage != null) {
      widget.editorState.clearScrollTarget();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToPage(targetPage);
        }
      });
    }
  }

  void _scrollToPage(int targetIndex) {
    final pages = widget.editorState.notebook.pages;
    if (targetIndex < 0 || targetIndex >= pages.length) return;

    double cumulativeY = 40.0;
    for (int i = 0; i < targetIndex; i++) {
      cumulativeY += pages[i].height + 44.0 + (i == 0 ? 0 : 36.0);
    }
    if (targetIndex > 0) {
      cumulativeY += 36.0;
    }

    final matrix = _transformController.value.clone();
    final scale = matrix.getMaxScaleOnAxis();
    if (scale <= 0) return;

    matrix.storage[13] = 20.0 - (cumulativeY * scale);
    _transformController.value = matrix;
  }

  void _onTransformChanged() {
    _updateVisibleRange();
  }

  void _updateVisibleRange() {
    final pages = widget.editorState.notebook.pages;
    if (pages.isEmpty) return;

    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    if (scale <= 0) return;

    final ty = matrix.storage[13];
    // Document space visible Y with 1500px pre-rendering buffer above and below
    final visibleTopDoc = (-ty) / scale - 1500;
    final visibleBottomDoc = (-ty + _viewportHeight) / scale + 1500;

    double cumulativeY = 40.0;
    int start = 0;
    int end = pages.length - 1;
    bool foundStart = false;

    for (int i = 0; i < pages.length; i++) {
      final pageHeight = pages[i].height + 44 + (i == 0 ? 0 : 36);
      final pageBottom = cumulativeY + pageHeight;

      if (!foundStart && pageBottom >= visibleTopDoc) {
        start = i > 0 ? i - 1 : 0;
        foundStart = true;
      }
      if (cumulativeY > visibleBottomDoc) {
        end = i;
        break;
      }
      cumulativeY = pageBottom;
    }

    if (start != _visibleStartPage || end != _visibleEndPage) {
      setState(() {
        _visibleStartPage = start;
        _visibleEndPage = end;
      });
    }
  }

  void _showEditTextDialog(BuildContext context, NotebookEditorState state, TextElementModel txt) {
    final controller = TextEditingController(text: txt.text);
    double fontSize = txt.fontSize;
    bool isBold = txt.isBold;
    bool isItalic = txt.isItalic;
    final strings = AppLocalizations.of(context).strings;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(strings.text),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 4,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.format_bold, color: isBold ? Colors.blue : Colors.grey),
                      tooltip: 'Bold',
                      onPressed: () => setDlgState(() => isBold = !isBold),
                    ),
                    IconButton(
                      icon: Icon(Icons.format_italic, color: isItalic ? Colors.blue : Colors.grey),
                      tooltip: 'Italic',
                      onPressed: () => setDlgState(() => isItalic = !isItalic),
                    ),
                    const SizedBox(width: 8),
                    Text('${fontSize.toInt()} pt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: fontSize.clamp(10.0, 72.0),
                        min: 10.0,
                        max: 72.0,
                        divisions: 31,
                        onChanged: (val) => setDlgState(() => fontSize = val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: strings.delete,
                      onPressed: () {
                        state.deleteTextElement(txt.id);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                state.updateTextElement(txt.copyWith(
                  text: controller.text,
                  fontSize: fontSize,
                  isBold: isBold,
                  isItalic: isItalic,
                ));
                Navigator.pop(ctx);
              },
              child: Text(strings.done),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _confirmDeleteImage(BuildContext context, NotebookEditorState state, String id) {
    final strings = AppLocalizations.of(context).strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deletePhoto),
        content: Text(strings.deletePhotoConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              state.deleteImageElement(id);
              Navigator.pop(context);
            },
            child: Text(strings.delete),
          ),
        ],
      ),
    );
  }

  void _showRecolorLassoDialog(BuildContext context, NotebookEditorState state) {
    final strings = AppLocalizations.of(context).strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.selectColor),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: Color(state.activeColor),
            onColorChanged: (newColor) {
              state.recolorLassoSelection(newColor.toARGB32());
              Navigator.pop(ctx);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePage(BuildContext context, NotebookEditorState state, int pageIndex) {
    final strings = AppLocalizations.of(context).strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deletePage),
        content: Text('${strings.deletePage} ${pageIndex + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              state.deletePageAt(pageIndex);
              Navigator.pop(ctx);
            },
            child: Text(strings.deletePage),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.editorState;
    final strings = AppLocalizations.of(context).strings;
    final pages = state.notebook.pages;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        return Container(
          color: Colors.grey.shade300,
          child: Stack(
            children: [
              // Zoomable & Pannable Document Viewport with continuous vertical pages flow
              InteractiveViewer(
                transformationController: _transformController,
                panEnabled: !_isDrawingWithStylus,
                scaleEnabled: !_isDrawingWithStylus,
                minScale: 0.25,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.symmetric(horizontal: 400, vertical: 800),
                constrained: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < pages.length; i++)
                        _buildPageItem(context, state, i, pages[i], strings),
                      _buildAddPageButton(context, state, strings),
                    ],
                  ),
                ),
              ),

              // Screen Ruler Overlay (if enabled)
              if (state.isRulerEnabled)
                RulerOverlay(
                  position: state.rulerPosition,
                  angle: state.rulerAngle,
                  onTransform: (delta, angleDelta) {
                    state.updateRulerTransform(delta, angleDelta);
                  },
                  onClose: () => state.toggleRuler(),
                ),

              // Lasso Selection Actions Bar
              () {
                final totalSelected = state.selectedStrokeIds.length +
                    state.selectedTextIds.length +
                    state.selectedImageIds.length;
                if (totalSelected == 0) return const SizedBox.shrink();

                return Positioned(
                  top: 16,
                  right: 16,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalSelected ${strings.lasso}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            tooltip: strings.deletePage,
                            onPressed: () => state.deleteLassoSelection(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            tooltip: strings.cancel,
                            onPressed: () => state.clearLassoSelection(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageItem(
    BuildContext context,
    NotebookEditorState state,
    int pageIndex,
    PageModel page,
    AppStrings strings,
  ) {
    final isPdf = state.notebook.sourcePdfPath != null;
    final isVisible = pageIndex >= _visibleStartPage && pageIndex <= _visibleEndPage;

    final header = Container(
      width: page.width,
      margin: EdgeInsets.only(top: pageIndex == 0 ? 0 : 36, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf : Icons.article_outlined,
            size: 18,
            color: isPdf ? Colors.red.shade600 : Colors.blue.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            '${strings.page} ${pageIndex + 1}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          if (state.notebook.pages.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: strings.deletePage,
              onPressed: () => _confirmDeletePage(context, state, pageIndex),
            ),
        ],
      ),
    );

    if (!isVisible) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          header,
          Container(
            width: page.width,
            height: page.height,
            decoration: BoxDecoration(
              color: page.template.backgroundColor,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: isPdf
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 48, color: Colors.black26),
                        const SizedBox(height: 8),
                        Text(
                          '${strings.page} ${pageIndex + 1}',
                          style: const TextStyle(color: Colors.black38, fontSize: 14),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        header,

        // Page Canvas
        Listener(
          onPointerDown: (event) {
            final canvasPt = Offset(
              event.localPosition.dx.clamp(0.0, page.width),
              event.localPosition.dy.clamp(0.0, page.height),
            );

            if (_isPointerOverInteractive(canvasPt, page, state, pageIndex)) {
              return;
            }

            if (state.activeTool == ToolType.textBox) {
              state.setActivePageIndex(pageIndex);
              state.addTextElement('${strings.text}...', canvasPt);
              state.setTool(ToolType.fountainPen);
              return;
            }

            final canDraw = state.palmRejection.shouldAcceptPointerForInking(event);
            if (canDraw && _activeDrawingPointerId == null) {
              _activeDrawingPointerId = event.pointer;
              state.setActivePageIndex(pageIndex);
              setState(() {
                _isDrawingWithStylus = true;
                _drawingPageIndex = pageIndex;
              });
              state.startStroke(Point2D(
                x: canvasPt.dx,
                y: canvasPt.dy,
                pressure: event.pressure > 0 ? event.pressure : 1.0,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));
            }
          },
          onPointerMove: (event) {
            if (_isDrawingWithStylus && _drawingPageIndex == pageIndex && event.pointer == _activeDrawingPointerId) {
              final canvasPt = Offset(
                event.localPosition.dx.clamp(0.0, page.width),
                event.localPosition.dy.clamp(0.0, page.height),
              );
              state.appendStrokePoint(Point2D(
                x: canvasPt.dx,
                y: canvasPt.dy,
                pressure: event.pressure > 0 ? event.pressure : 1.0,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));
            }
          },
          onPointerUp: (event) {
            state.palmRejection.handlePointerUp(event);
            if (_isDrawingWithStylus && _drawingPageIndex == pageIndex && event.pointer == _activeDrawingPointerId) {
              _activeDrawingPointerId = null;
              setState(() {
                _isDrawingWithStylus = false;
                _drawingPageIndex = null;
              });
              state.finishStroke(DateTime.now().millisecondsSinceEpoch);
            }
          },
          onPointerCancel: (event) {
            state.palmRejection.handlePointerCancel(event);
            if (_isDrawingWithStylus && _drawingPageIndex == pageIndex && event.pointer == _activeDrawingPointerId) {
              _activeDrawingPointerId = null;
              setState(() {
                _isDrawingWithStylus = false;
                _drawingPageIndex = null;
              });
              state.finishStroke(DateTime.now().millisecondsSinceEpoch);
            }
          },
          child: Container(
            width: page.width,
            height: page.height,
            clipBehavior: Clip.none,
            decoration: BoxDecoration(
              color: page.template.backgroundColor,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 0. PDF Page background rendering if PDF notebook
                if (isPdf)
                  Positioned.fill(
                    child: _PdfPageBackground(
                      pdfPath: state.notebook.sourcePdfPath!,
                      pageIndex: page.pdfPageIndex ?? pageIndex,
                      pageLabel: strings.page,
                    ),
                  ),

                // 1. Paper template pattern (ruled lines, grid, cornell) for regular notebooks
                if (!isPdf)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: PaperGridPainter(template: page.template),
                    ),
                  ),

                // 2. Background Images (rendered behind ink strokes)
                ...page.imageElements
                    .where((img) => img.isBackground)
                    .map((img) => _buildImageWidget(context, state, page, pageIndex, img, strings)),

                // 3. Vector Inking Canvas (Strokes + Highlighter + Lasso)
                Positioned.fill(
                  child: CustomPaint(
                    painter: CanvasPainter(
                      strokes: page.strokes,
                      activeStrokePoints:
                          (_isDrawingWithStylus && _drawingPageIndex == pageIndex) ? state.activeStrokePoints : const [],
                      activeTool: state.activeTool,
                      activeColor: state.activeColor,
                      activeStrokeWidth: state.activeTool == ToolType.highlighter
                          ? state.highlighterWidth
                          : state.activeStrokeWidth,
                      lassoPoints: (state.currentPageIndex == pageIndex && state.isLassoActive) ? state.lassoPoints : const [],
                      isLassoActive: state.currentPageIndex == pageIndex && state.isLassoActive,
                      selectedStrokeIds: state.currentPageIndex == pageIndex ? state.selectedStrokeIds : const {},
                    ),
                  ),
                ),

                // 4. Foreground Images (rendered above strokes)
                ...page.imageElements
                    .where((img) => !img.isBackground)
                    .map((img) => _buildImageWidget(context, state, page, pageIndex, img, strings)),

                // 5. Text Boxes (tap to edit, drag to move, resize handle)
                ...page.textElements.map((txt) => _buildTextWidget(context, state, page, pageIndex, txt, strings)),

                // 6. Interactive Lasso Selection Bounding Box & Action Menu
                if (state.currentPageIndex == pageIndex &&
                    (state.selectedStrokeIds.isNotEmpty || state.selectedTextIds.isNotEmpty || state.selectedImageIds.isNotEmpty) &&
                    state.lassoBoundingBox != null) ...[
                  () {
                    final bbox = state.lassoBoundingBox!.inflate(8.0);
                    final isTop = bbox.top > 56;
                    final menuY = isTop ? bbox.top - 46.0 : bbox.bottom + 10.0;
                    final menuX = (bbox.center.dx - 140.0).clamp(10.0, (page.width - 290.0).clamp(10.0, double.infinity));

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: bbox.left,
                          top: bbox.top,
                          width: bbox.width,
                          height: bbox.height,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              final scale = _transformController.value.getMaxScaleOnAxis();
                              final effectiveScale = scale > 0 ? scale : 1.0;
                              state.translateLassoSelection(details.delta.dx / effectiveScale, details.delta.dy / effectiveScale);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: Colors.blue.shade600,
                                  width: 1.8,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: menuX,
                          top: menuY,
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.white,
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
                                    tooltip: strings.duplicate,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => state.duplicateLassoSelection(),
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    icon: const Icon(Icons.palette_outlined, size: 18, color: Colors.indigo),
                                    tooltip: strings.color,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showRecolorLassoDialog(context, state),
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    icon: const Icon(Icons.flip_to_front, size: 18, color: Colors.blueGrey),
                                    tooltip: strings.bringToFront,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => state.bringLassoSelectionToFront(),
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    icon: const Icon(Icons.flip_to_back, size: 18, color: Colors.blueGrey),
                                    tooltip: strings.sendToBack,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => state.sendLassoSelectionToBack(),
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    tooltip: strings.delete,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => state.deleteLassoSelection(),
                                  ),
                                  const VerticalDivider(indent: 8, endIndent: 8, width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                    tooltip: strings.cancel,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => state.clearLassoSelection(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isPointerOverInteractive(Offset canvasPt, PageModel page, NotebookEditorState state, int pageIndex) {
    if (state.currentPageIndex == pageIndex &&
        (state.selectedStrokeIds.isNotEmpty || state.selectedTextIds.isNotEmpty || state.selectedImageIds.isNotEmpty) &&
        state.lassoBoundingBox != null) {
      if (state.lassoBoundingBox!.inflate(14.0).contains(canvasPt)) {
        return true;
      }
    }

    for (final txt in page.textElements) {
      final lines = txt.text.split('\n');
      final avgCharWidth = txt.fontSize * 0.6;
      final availableWidth = math.max(20.0, txt.width - 16.0);
      int estimatedLineCount = 0;
      for (final line in lines) {
        final lineChars = line.isEmpty ? 1 : line.length;
        estimatedLineCount += math.max(1, (lineChars * avgCharWidth / availableWidth).ceil());
      }
      final approxHeight = math.max(40.0, estimatedLineCount * (txt.fontSize * 1.35) + 24.0);
      final rect = Rect.fromLTWH(txt.x - 12, txt.y - 12, txt.width + 24, approxHeight + 24);
      final deleteBadgeRect = Rect.fromLTWH(txt.x + txt.width - 16, txt.y - 16, 32, 32);
      final resizeBadgeRect = Rect.fromLTWH(txt.x + txt.width - 16, txt.y + approxHeight - 16, 32, 32);

      if (rect.contains(canvasPt) || deleteBadgeRect.contains(canvasPt) || resizeBadgeRect.contains(canvasPt)) {
        return true;
      }
    }

    for (final img in page.imageElements) {
      if (state.activeTool == ToolType.image) {
        final rect = Rect.fromLTWH(img.x - 12, img.y - 12, img.width + 24, img.height + 24);
        if (rect.contains(canvasPt)) {
          return true;
        }
      }

      final layerToggleRect = Rect.fromLTWH(img.x - 16, img.y - 16, 36, 36);
      final deleteRect = Rect.fromLTWH(img.x + img.width - 20, img.y - 16, 36, 36);
      final resizeRect = Rect.fromLTWH(img.x + img.width - 16, img.y + img.height - 16, 36, 36);

      if (layerToggleRect.contains(canvasPt) || deleteRect.contains(canvasPt) || resizeRect.contains(canvasPt)) {
        return true;
      }

      if (!img.isBackground) {
        final rect = Rect.fromLTWH(img.x - 12, img.y - 12, img.width + 24, img.height + 24);
        if (rect.contains(canvasPt)) {
          return true;
        }
      }
    }

    return false;
  }

  Widget _buildImageWidget(
    BuildContext context,
    NotebookEditorState state,
    PageModel page,
    int pageIndex,
    ImageElementModel img,
    AppStrings strings,
  ) {
    return Positioned(
      left: img.x,
      top: img.y,
      width: img.width,
      height: img.height,
      child: Transform.rotate(
        angle: img.rotation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onPanStart: (_) {
                if (state.currentPageIndex != pageIndex) {
                  state.setActivePageIndex(pageIndex);
                }
              },
              onPanUpdate: (details) {
                final scale = _transformController.value.getMaxScaleOnAxis();
                final effectiveScale = scale > 0 ? scale : 1.0;
                final delta = details.delta / effectiveScale;
                state.moveImageElementWithCrossPage(
                  img.id,
                  Offset(img.x + delta.dx, img.y + delta.dy),
                );
              },
              onLongPress: () => _confirmDeleteImage(context, state, img.id),
              child: Container(
                width: img.width,
                height: img.height,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: img.isBackground
                        ? Colors.grey.withValues(alpha: 0.4)
                        : Colors.blue.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: img.rawBytes != null
                    ? Image.memory(
                        img.rawBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
                          ),
                        ),
                      )
                    : (img.localPath != null
                        ? Image.file(
                            File(img.localPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.blue.shade100,
                            child: const Icon(Icons.image, size: 48, color: Colors.blue),
                          )),
              ),
            ),
            // Layer toggle badge at top-left
            Positioned(
              left: -8,
              top: -8,
              child: GestureDetector(
                onTap: () {
                  if (img.isBackground) {
                    state.bringImageToFront(img.id);
                  } else {
                    state.sendImageToBack(img.id);
                  }
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: Icon(
                    img.isBackground ? Icons.flip_to_front : Icons.flip_to_back,
                    size: 13,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
            // Corner resize handle at bottom-right
            Positioned(
              right: -10,
              bottom: -10,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final scale = _transformController.value.getMaxScaleOnAxis();
                  final effectiveScale = scale > 0 ? scale : 1.0;
                  final delta = details.delta / effectiveScale;
                  state.resizeImageElement(
                    img.id,
                    (img.width + delta.dx).clamp(40.0, page.width * 2),
                    (img.height + delta.dy).clamp(40.0, page.height * 2),
                  );
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: const Icon(Icons.aspect_ratio, size: 14, color: Colors.blue),
                ),
              ),
            ),
            // Delete badge at top-right
            Positioned(
              right: -8,
              top: -8,
              child: GestureDetector(
                onTap: () => _confirmDeleteImage(context, state, img.id),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextWidget(
    BuildContext context,
    NotebookEditorState state,
    PageModel page,
    int pageIndex,
    TextElementModel txt,
    AppStrings strings,
  ) {
    return Positioned(
      left: txt.x,
      top: txt.y,
      width: txt.width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => _showEditTextDialog(context, state, txt),
            onPanStart: (_) {
              if (state.currentPageIndex != pageIndex) {
                state.setActivePageIndex(pageIndex);
              }
            },
            onPanUpdate: (details) {
              final scale = _transformController.value.getMaxScaleOnAxis();
              final effectiveScale = scale > 0 ? scale : 1.0;
              final delta = details.delta / effectiveScale;
              state.moveTextElementWithCrossPage(
                txt.id,
                Offset(txt.x + delta.dx, txt.y + delta.dy),
              );
            },
            child: Container(
              width: txt.width,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Text(
                txt.text,
                style: TextStyle(
                  fontSize: txt.fontSize,
                  color: txt.color,
                  fontWeight: txt.isBold ? FontWeight.bold : FontWeight.normal,
                  fontStyle: txt.isItalic ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ),
          // Delete badge at top-right
          Positioned(
            right: -8,
            top: -8,
            child: GestureDetector(
              onTap: () => state.deleteTextElement(txt.id),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
          // Corner resize handle at bottom-right (proportional font scaling)
          Positioned(
            right: -8,
            bottom: -8,
            child: GestureDetector(
              onPanUpdate: (details) {
                final scale = _transformController.value.getMaxScaleOnAxis();
                final effectiveScale = scale > 0 ? scale : 1.0;
                final delta = details.delta / effectiveScale;
                final maxWidth = math.max(80.0, page.width - txt.x);
                final newWidth = (txt.width + delta.dx).clamp(80.0, maxWidth);
                final widthRatio = newWidth / txt.width;
                final newFontSize = (txt.fontSize * widthRatio).clamp(10.0, 72.0);
                state.updateTextElement(txt.copyWith(
                  width: newWidth,
                  fontSize: newFontSize,
                ));
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent, width: 1.8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: const Icon(Icons.aspect_ratio, size: 12, color: Colors.blueAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPageButton(BuildContext context, NotebookEditorState state, AppStrings strings) {
    return Container(
      margin: const EdgeInsets.only(top: 40, bottom: 80),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_circle, size: 22),
        label: Text(
          '${strings.addPage} (${state.notebook.pages.length + 1})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 6,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: () {
          state.addNewPage();
        },
      ),
    );
  }
}

class _PdfPageBackground extends StatefulWidget {
  final String pdfPath;
  final int pageIndex;
  final String pageLabel;

  const _PdfPageBackground({
    required this.pdfPath,
    required this.pageIndex,
    required this.pageLabel,
  });

  @override
  State<_PdfPageBackground> createState() => _PdfPageBackgroundState();
}

class _PdfPageBackgroundState extends State<_PdfPageBackground> {
  Future<Uint8List?>? _renderFuture;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void didUpdateWidget(covariant _PdfPageBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfPath != widget.pdfPath || oldWidget.pageIndex != widget.pageIndex) {
      _loadPage();
    }
  }

  void _loadPage() {
    _renderFuture = PdfVirtualCache().renderPage(widget.pdfPath, widget.pageIndex);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _renderFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
            );
          }
          final strings = AppLocalizations.of(context).strings;
          return Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, color: Colors.red.shade400, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    '${strings.failedToLoadPage} (${widget.pageIndex + 1})',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(strings.retry),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () {
                      setState(() {
                        _loadPage();
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }
        return Container(
          color: Colors.white,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.pageLabel} ${widget.pageIndex + 1}...',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
