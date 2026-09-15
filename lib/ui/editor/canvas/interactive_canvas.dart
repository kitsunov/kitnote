import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/point_model.dart';
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

  Offset _screenToCanvas(Offset screenOffset) {
    final matrix = _transformController.value;
    final inverted = Matrix4.tryInvert(matrix);
    if (inverted == null) return screenOffset;
    final transformed = MatrixUtils.transformPoint(inverted, screenOffset);
    return transformed;
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.editorState;
    final page = state.currentPage;

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
                    _isDrawingWithStylus = true;
                    final canvasPt = _screenToCanvas(event.localPosition);
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
                    final canvasPt = _screenToCanvas(event.localPosition);
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
                    _isDrawingWithStylus = false;
                    state.finishStroke();
                  }
                },
                onPointerCancel: (event) {
                  state.palmRejection.handlePointerCancel(event);
                  if (_isDrawingWithStylus) {
                    _isDrawingWithStylus = false;
                    state.finishStroke();
                  }
                },
                child: Container(
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
                  child: Stack(
                    children: [
                      // 1. Paper template pattern (ruled lines, grid, cornell)
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
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                              ),
                              child: img.localPath != null
                                  ? Image.file(File(img.localPath!), fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.blue.shade100,
                                      child: const Icon(Icons.image, size: 48, color: Colors.blue),
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

                      // 4. Text Boxes
                      ...page.textElements.map((txt) {
                        return Positioned(
                          left: txt.x,
                          top: txt.y,
                          width: txt.width,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
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
        ],
      ),
    );
  }
}
