import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../engine/pdf_virtual_cache.dart';
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

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final state = widget.editorState;
    final page = state.currentPage;
    final strings = AppLocalizations.of(context).strings;

    return Container(
      color: Colors.grey.shade300,
      child: Stack(
        children: [
          // Zoomable & Pannable Document Viewport
          InteractiveViewer(
            transformationController: _transformController,
            panEnabled: !_isDrawingWithStylus,
            scaleEnabled: !_isDrawingWithStylus,
            minScale: 0.3,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(400),
            child: Center(
              child: Listener(
                onPointerDown: (event) {
                  final canDraw = state.palmRejection.shouldAcceptPointerForInking(event);
                  if (canDraw) {
                    setState(() {
                      _isDrawingWithStylus = true;
                    });
                    // Coordinates on Listener are already in local canvas space
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
                  if (_isDrawingWithStylus) {
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
                  if (_isDrawingWithStylus) {
                    setState(() {
                      _isDrawingWithStylus = false;
                    });
                    state.finishStroke();
                  }
                },
                onPointerCancel: (event) {
                  state.palmRejection.handlePointerCancel(event);
                  if (_isDrawingWithStylus) {
                    setState(() {
                      _isDrawingWithStylus = false;
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
                      if (state.notebook.sourcePdfPath != null)
                        Positioned.fill(
                          child: FutureBuilder<Uint8List?>(
                            future: PdfVirtualCache().renderPage(
                              state.notebook.sourcePdfPath!,
                              page.pdfPageIndex ?? page.pageIndex,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.contain,
                                );
                              }
                              return const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                          ),
                        ),

                      // 1. Paper template pattern (ruled lines, grid, cornell) for regular notebooks
                      if (state.notebook.sourcePdfPath == null)
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
                            activeStrokePoints: state.activeStrokePoints,
                            activeTool: state.activeTool,
                            activeColor: state.activeColor,
                            activeStrokeWidth: state.activeStrokeWidth,
                            lassoPoints: state.lassoPoints,
                            isLassoActive: state.isLassoActive,
                            selectedStrokeIds: state.selectedStrokeIds,
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
            ),
          ),

          // 5. Screen Ruler Overlay (if enabled)
          if (state.isRulerEnabled)
            RulerOverlay(
              position: state.rulerPosition,
              angle: state.rulerAngle,
              onTransform: (delta, angleDelta) {
                state.updateRulerTransform(delta, angleDelta);
              },
              onClose: () => state.toggleRuler(),
            ),

          // 6. Lasso Selection Actions Bar
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
  }
}
