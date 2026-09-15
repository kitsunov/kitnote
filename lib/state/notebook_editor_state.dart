import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/geometry_utils.dart';
import '../engine/palm_rejection_manager.dart';
import '../engine/shape_recognizer.dart';
import '../models/image_element_model.dart';
import '../models/notebook_model.dart';
import '../models/page_model.dart';
import '../models/point_model.dart';
import '../models/stroke_model.dart';
import '../models/text_element_model.dart';
import '../models/tool_type.dart';
import '../services/storage_service.dart';

class PageUndoState {
  final List<StrokeModel> strokes;
  final List<TextElementModel> textElements;
  final List<ImageElementModel> imageElements;

  PageUndoState({
    required this.strokes,
    required this.textElements,
    required this.imageElements,
  });
}

class NotebookEditorState extends ChangeNotifier {
  NotebookModel notebook;
  int _currentPageIndex = 0;

  // Active Tool Configuration
  ToolType _activeTool = ToolType.fountainPen;
  int _activeColor = 0xFF0F172A; // Black default
  double _activeStrokeWidth = 3.0;
  final double _eraserRadius = 16.0;

  // Palm Rejection
  final PalmRejectionManager _palmRejection =
      PalmRejectionManager(mode: PalmRejectionMode.stylusOnly);

  // Ruler state
  bool _isRulerEnabled = false;
  Offset _rulerPosition = const Offset(200, 300);
  double _rulerAngle = 0.0; // In radians

  // Active inking stroke
  final List<Point2D> _activeStrokePoints = [];

  // Lasso selection
  final List<Offset> _lassoPoints = [];
  bool _isLassoActive = false;
  final Set<String> _selectedStrokeIds = {};
  final Set<String> _selectedTextIds = {};
  final Set<String> _selectedImageIds = {};

  // Undo / Redo stacks
  final List<PageUndoState> _undoStack = [];
  final List<PageUndoState> _redoStack = [];

  NotebookEditorState({required this.notebook});

  // Getters
  int get currentPageIndex => _currentPageIndex;
  ToolType get activeTool => _activeTool;
  int get activeColor => _activeColor;
  double get activeStrokeWidth => _activeStrokeWidth;
  double get eraserRadius => _eraserRadius;
  PalmRejectionManager get palmRejection => _palmRejection;
  bool get isRulerEnabled => _isRulerEnabled;
  Offset get rulerPosition => _rulerPosition;
  double get rulerAngle => _rulerAngle;
  List<Point2D> get activeStrokePoints => List.unmodifiable(_activeStrokePoints);
  List<Offset> get lassoPoints => List.unmodifiable(_lassoPoints);
  bool get isLassoActive => _isLassoActive;
  Set<String> get selectedStrokeIds => Set.unmodifiable(_selectedStrokeIds);
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  PageModel get currentPage {
    if (notebook.pages.isEmpty) {
      final defaultPage = PageModel(id: const Uuid().v4(), pageIndex: 0);
      notebook = notebook.copyWith(pages: [defaultPage]);
      return defaultPage;
    }
    if (_currentPageIndex >= notebook.pages.length) {
      _currentPageIndex = notebook.pages.length - 1;
    }
    return notebook.pages[_currentPageIndex];
  }

  // Tool Selection
  void setTool(ToolType tool) {
    _activeTool = tool;
    _clearLassoSelection();
    notifyListeners();
  }

  void setColor(int color) {
    _activeColor = color;
    if (_selectedStrokeIds.isNotEmpty) {
      _recordUndoState();
      // Change color of selected strokes
      final updatedStrokes = currentPage.strokes.map((s) {
        if (_selectedStrokeIds.contains(s.id)) {
          return s.copyWith(colorValue: color);
        }
        return s;
      }).toList();
      _updateCurrentPageStrokes(updatedStrokes);
    }
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _activeStrokeWidth = width;
    notifyListeners();
  }

  void toggleRuler() {
    _isRulerEnabled = !_isRulerEnabled;
    notifyListeners();
  }

  void updateRulerTransform(Offset delta, double rotationDelta) {
    _rulerPosition += delta;
    _rulerAngle += rotationDelta;
    notifyListeners();
  }

  void togglePalmRejectionMode() {
    if (_palmRejection.mode == PalmRejectionMode.stylusOnly) {
      _palmRejection.mode = PalmRejectionMode.stylusAndTouch;
    } else {
      _palmRejection.mode = PalmRejectionMode.stylusOnly;
    }
    notifyListeners();
  }

  // Page Navigation
  void goToPage(int index) {
    if (index >= 0 && index < notebook.pages.length) {
      _currentPageIndex = index;
      _undoStack.clear();
      _redoStack.clear();
      _clearLassoSelection();
      notifyListeners();
    }
  }

  void nextPage() {
    if (_currentPageIndex < notebook.pages.length - 1) {
      goToPage(_currentPageIndex + 1);
    }
  }

  void previousPage() {
    if (_currentPageIndex > 0) {
      goToPage(_currentPageIndex - 1);
    }
  }

  void addNewPage({int? atIndex}) {
    _recordUndoState();
    final newId = const Uuid().v4();
    final insertIdx = atIndex ?? (notebook.pages.length);
    final newPage = PageModel(
      id: newId,
      pageIndex: insertIdx,
      template: currentPage.template,
    );

    final updatedPages = List<PageModel>.from(notebook.pages);
    updatedPages.insert(insertIdx, newPage);

    // Reindex
    for (int i = 0; i < updatedPages.length; i++) {
      updatedPages[i] = updatedPages[i].copyWith(pageIndex: i);
    }

    notebook = notebook.copyWith(
      pages: updatedPages,
      updatedAt: DateTime.now(),
    );
    _currentPageIndex = insertIdx;
    _saveToStorage();
    notifyListeners();
  }

  void duplicateCurrentPage() {
    _recordUndoState();
    final copy = currentPage.copyWith(
      id: const Uuid().v4(),
      pageIndex: _currentPageIndex + 1,
    );
    final updatedPages = List<PageModel>.from(notebook.pages);
    updatedPages.insert(_currentPageIndex + 1, copy);

    for (int i = 0; i < updatedPages.length; i++) {
      updatedPages[i] = updatedPages[i].copyWith(pageIndex: i);
    }

    notebook = notebook.copyWith(
      pages: updatedPages,
      updatedAt: DateTime.now(),
    );
    _currentPageIndex = _currentPageIndex + 1;
    _saveToStorage();
    notifyListeners();
  }

  void deleteCurrentPage() {
    if (notebook.pages.length <= 1) return; // Keep at least 1 page

    _recordUndoState();
    final updatedPages = List<PageModel>.from(notebook.pages)..removeAt(_currentPageIndex);

    for (int i = 0; i < updatedPages.length; i++) {
      updatedPages[i] = updatedPages[i].copyWith(pageIndex: i);
    }

    notebook = notebook.copyWith(
      pages: updatedPages,
      updatedAt: DateTime.now(),
    );
    if (_currentPageIndex >= updatedPages.length) {
      _currentPageIndex = updatedPages.length - 1;
    }
    _saveToStorage();
    notifyListeners();
  }

  // Drawing Lifecycle
  void startStroke(Point2D point) {
    if (_activeTool.isEraser) {
      _recordUndoState();
      _handleEraserPoint(point.toOffset());
      return;
    }

    if (_activeTool == ToolType.lasso) {
      _isLassoActive = true;
      _lassoPoints.clear();
      _lassoPoints.add(point.toOffset());
      notifyListeners();
      return;
    }

    _activeStrokePoints.clear();

    Point2D actualPoint = point;
    if (_isRulerEnabled) {
      final projected = GeometryUtils.projectOntoRuler(point.toOffset(), _rulerPosition, _rulerAngle);
      actualPoint = Point2D(x: projected.dx, y: projected.dy, pressure: point.pressure, timestamp: point.timestamp);
    }

    _activeStrokePoints.add(actualPoint);
    notifyListeners();
  }

  void appendStrokePoint(Point2D point) {
    if (_activeTool.isEraser) {
      _handleEraserPoint(point.toOffset());
      return;
    }

    if (_activeTool == ToolType.lasso) {
      _lassoPoints.add(point.toOffset());
      notifyListeners();
      return;
    }

    Point2D actualPoint = point;
    if (_isRulerEnabled) {
      final projected = GeometryUtils.projectOntoRuler(point.toOffset(), _rulerPosition, _rulerAngle);
      actualPoint = Point2D(x: projected.dx, y: projected.dy, pressure: point.pressure, timestamp: point.timestamp);
    }

    _activeStrokePoints.add(actualPoint);
    notifyListeners();
  }

  void finishStroke() {
    if (_activeTool.isEraser) {
      _saveToStorage();
      return;
    }

    if (_activeTool == ToolType.lasso) {
      _finishLassoSelection();
      return;
    }

    if (_activeStrokePoints.isEmpty) return;

    _recordUndoState();

    final opacity = _activeTool == ToolType.highlighter ? 0.35 : 1.0;
    final strokeWidth = _activeTool == ToolType.highlighter
        ? _activeStrokeWidth * 3.5
        : _activeStrokeWidth;

    StrokeModel newStroke = StrokeModel(
      id: const Uuid().v4(),
      points: List.from(_activeStrokePoints),
      colorValue: _activeColor,
      strokeWidth: strokeWidth,
      opacity: opacity,
      toolType: _activeTool,
    );

    // Auto-detect shapes if pen was held or line snapped
    if (!_isRulerEnabled && _activeTool != ToolType.highlighter) {
      final recognized = ShapeRecognizer.tryRecognizeShape(newStroke);
      if (recognized != null) {
        newStroke = recognized;
      }
    }

    final updatedStrokes = List<StrokeModel>.from(currentPage.strokes)..add(newStroke);
    _updateCurrentPageStrokes(updatedStrokes);

    _activeStrokePoints.clear();
    _saveToStorage();
    notifyListeners();
  }

  // Eraser Logic
  void _handleEraserPoint(Offset eraserPos) {
    final strokes = currentPage.strokes;
    if (strokes.isEmpty) return;

    if (_activeTool == ToolType.strokeEraser) {
      final remainingStrokes = strokes.where((s) {
        return !GeometryUtils.isStrokeHitByPoint(s, eraserPos, _eraserRadius);
      }).toList();

      if (remainingStrokes.length != strokes.length) {
        _updateCurrentPageStrokes(remainingStrokes);
        notifyListeners();
      }
    } else if (_activeTool == ToolType.pixelEraser) {
      // For pixel eraser: remove hit strokes or split segments
      final remainingStrokes = strokes.where((s) {
        return !GeometryUtils.isStrokeHitByPoint(s, eraserPos, _eraserRadius);
      }).toList();

      if (remainingStrokes.length != strokes.length) {
        _updateCurrentPageStrokes(remainingStrokes);
        notifyListeners();
      }
    }
  }

  // Lasso Logic
  void _finishLassoSelection() {
    _isLassoActive = false;
    if (_lassoPoints.length < 3) {
      _clearLassoSelection();
      notifyListeners();
      return;
    }

    _selectedStrokeIds.clear();
    for (final stroke in currentPage.strokes) {
      if (GeometryUtils.isStrokeEnclosedInPolygon(stroke, _lassoPoints)) {
        _selectedStrokeIds.add(stroke.id);
      }
    }

    notifyListeners();
  }

  void translateLassoSelection(double dx, double dy) {
    if (_selectedStrokeIds.isEmpty) return;
    _recordUndoState();

    final updated = currentPage.strokes.map((s) {
      if (_selectedStrokeIds.contains(s.id)) {
        return s.translate(dx, dy);
      }
      return s;
    }).toList();

    _updateCurrentPageStrokes(updated);
    _saveToStorage();
    notifyListeners();
  }

  void deleteLassoSelection() {
    if (_selectedStrokeIds.isEmpty) return;
    _recordUndoState();

    final updated = currentPage.strokes.where((s) => !_selectedStrokeIds.contains(s.id)).toList();
    _updateCurrentPageStrokes(updated);
    _clearLassoSelection();
    _saveToStorage();
    notifyListeners();
  }

  void clearLassoSelection() {
    _lassoPoints.clear();
    _selectedStrokeIds.clear();
    _selectedTextIds.clear();
    _selectedImageIds.clear();
    notifyListeners();
  }

  void _clearLassoSelection() {
    _lassoPoints.clear();
    _selectedStrokeIds.clear();
    _selectedTextIds.clear();
    _selectedImageIds.clear();
  }

  // Text Elements
  void addTextElement(String text, Offset position) {
    _recordUndoState();
    final newText = TextElementModel(
      id: const Uuid().v4(),
      text: text,
      x: position.dx,
      y: position.dy,
      colorValue: _activeColor,
    );

    final updated = List<TextElementModel>.from(currentPage.textElements)..add(newText);
    _updateCurrentPageTextElements(updated);
    _saveToStorage();
    notifyListeners();
  }

  void updateTextElement(TextElementModel updated) {
    _recordUndoState();
    final list = currentPage.textElements.map((t) => t.id == updated.id ? updated : t).toList();
    _updateCurrentPageTextElements(list);
    _saveToStorage();
    notifyListeners();
  }

  void deleteTextElement(String id) {
    _recordUndoState();
    final list = currentPage.textElements.where((t) => t.id != id).toList();
    _updateCurrentPageTextElements(list);
    _saveToStorage();
    notifyListeners();
  }

  // Image Elements
  void addImageElement(String path, Offset position, double width, double height) {
    _recordUndoState();
    final newImg = ImageElementModel(
      id: const Uuid().v4(),
      localPath: path,
      x: position.dx,
      y: position.dy,
      width: width,
      height: height,
    );

    final updated = List<ImageElementModel>.from(currentPage.imageElements)..add(newImg);
    _updateCurrentPageImageElements(updated);
    _saveToStorage();
    notifyListeners();
  }

  void updateImageElement(ImageElementModel updated) {
    _recordUndoState();
    final list = currentPage.imageElements.map((i) => i.id == updated.id ? updated : i).toList();
    _updateCurrentPageImageElements(list);
    _saveToStorage();
    notifyListeners();
  }

  void deleteImageElement(String id) {
    _recordUndoState();
    final list = currentPage.imageElements.where((i) => i.id != id).toList();
    _updateCurrentPageImageElements(list);
    _saveToStorage();
    notifyListeners();
  }

  // Undo / Redo
  void _recordUndoState() {
    _undoStack.add(PageUndoState(
      strokes: List.from(currentPage.strokes),
      textElements: List.from(currentPage.textElements),
      imageElements: List.from(currentPage.imageElements),
    ));
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _redoStack.add(PageUndoState(
      strokes: List.from(currentPage.strokes),
      textElements: List.from(currentPage.textElements),
      imageElements: List.from(currentPage.imageElements),
    ));

    _updateCurrentPageAll(
      strokes: previous.strokes,
      textElements: previous.textElements,
      imageElements: previous.imageElements,
    );
    _saveToStorage();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(PageUndoState(
      strokes: List.from(currentPage.strokes),
      textElements: List.from(currentPage.textElements),
      imageElements: List.from(currentPage.imageElements),
    ));

    _updateCurrentPageAll(
      strokes: next.strokes,
      textElements: next.textElements,
      imageElements: next.imageElements,
    );
    _saveToStorage();
    notifyListeners();
  }

  // Helpers to update page immutably
  void _updateCurrentPageStrokes(List<StrokeModel> strokes) {
    _updateCurrentPageAll(strokes: strokes);
  }

  void _updateCurrentPageTextElements(List<TextElementModel> textElements) {
    _updateCurrentPageAll(textElements: textElements);
  }

  void _updateCurrentPageImageElements(List<ImageElementModel> imageElements) {
    _updateCurrentPageAll(imageElements: imageElements);
  }

  void _updateCurrentPageAll({
    List<StrokeModel>? strokes,
    List<TextElementModel>? textElements,
    List<ImageElementModel>? imageElements,
  }) {
    final updatedPage = currentPage.copyWith(
      strokes: strokes,
      textElements: textElements,
      imageElements: imageElements,
    );

    final updatedPages = List<PageModel>.from(notebook.pages);
    updatedPages[_currentPageIndex] = updatedPage;

    notebook = notebook.copyWith(
      pages: updatedPages,
      updatedAt: DateTime.now(),
    );
  }

  void _saveToStorage() {
    StorageService().saveNotebook(notebook);
  }
}
