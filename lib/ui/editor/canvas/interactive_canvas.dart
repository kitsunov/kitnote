import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../engine/pdf_virtual_cache.dart';
import '../../../models/page_model.dart';
import '../../../models/point_model.dart';
import '../../../models/text_element_model.dart';
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
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: strings.deletePage,
                    onPressed: () {
                      state.deleteTextElement(txt.id);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ],
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
    );
  }

  void _confirmDeleteImage(BuildContext context, NotebookEditorState state, String id) {
    final strings = AppLocalizations.of(context).strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.photo),
        content: Text('${strings.deleteNotebook}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              state.deleteImageElement(id);
              Navigator.pop(context);
            },
            child: Text(strings.deletePage),
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
              if (state.selectedStrokeIds.isNotEmpty)
                Positioned(
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
                            '${state.selectedStrokeIds.length} ${strings.lasso}',
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
                ),
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
            final canDraw = state.palmRejection.shouldAcceptPointerForInking(event);
            if (canDraw && _activeDrawingPointerId == null) {
              _activeDrawingPointerId = event.pointer;
              state.setActivePageIndex(pageIndex);
              setState(() {
                _isDrawingWithStylus = true;
                _drawingPageIndex = pageIndex;
              });
              final canvasPt = Offset(
                event.localPosition.dx.clamp(0.0, page.width),
                event.localPosition.dy.clamp(0.0, page.height),
              );
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
              state.finishStroke();
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
              state.finishStroke();
            }
          },
          child: Container(
            width: page.width,
            height: page.height,
            clipBehavior: Clip.hardEdge,
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

                // 2. Images embedded on page
                ...page.imageElements.map((img) {
                  return Positioned(
                    left: img.x,
                    top: img.y,
                    width: img.width,
                    height: img.height,
                    child: Transform.rotate(
                      angle: img.rotation,
                      child: GestureDetector(
                        onLongPress: () => _confirmDeleteImage(context, state, img.id),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                          ),
                          child: img.localPath != null
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
                                ),
                        ),
                      ),
                    ),
                  );
                }),

                // 3. Vector Inking Canvas (Strokes + Highlighter + Lasso)
                Positioned.fill(
                  child: CustomPaint(
                    painter: CanvasPainter(
                      strokes: page.strokes,
                      activeStrokePoints:
                          (_isDrawingWithStylus && _drawingPageIndex == pageIndex) ? state.activeStrokePoints : const [],
                      activeTool: state.activeTool,
                      activeColor: state.activeColor,
                      activeStrokeWidth: state.activeStrokeWidth,
                      lassoPoints: (state.currentPageIndex == pageIndex && state.isLassoActive) ? state.lassoPoints : const [],
                      isLassoActive: state.currentPageIndex == pageIndex && state.isLassoActive,
                      selectedStrokeIds: state.currentPageIndex == pageIndex ? state.selectedStrokeIds : const {},
                    ),
                  ),
                ),

                // 4. Text Boxes (tap to edit)
                ...page.textElements.map((txt) {
                  return Positioned(
                    left: txt.x,
                    top: txt.y,
                    width: txt.width,
                    child: GestureDetector(
                      onTap: () => _showEditTextDialog(context, state, txt),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(4),
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
                  );
                }),
              ],
            ),
          ),
        ),
      ],
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
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Icon(Icons.error_outline, color: Colors.red.shade300, size: 36),
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
