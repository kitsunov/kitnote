import 'package:flutter/foundation.dart';

class WorkspaceState extends ChangeNotifier {
  final List<String> _openNotebookIds = [];
  int _activeTabIndex = 0;

  // Split-screen state
  bool _isSplitScreen = false;
  String? _secondaryNotebookId;
  double _splitRatio = 0.5; // 50/50 default

  List<String> get openNotebookIds => List.unmodifiable(_openNotebookIds);
  int get activeTabIndex => _activeTabIndex;
  bool get isSplitScreen => _isSplitScreen;
  String? get secondaryNotebookId => _secondaryNotebookId;
  double get splitRatio => _splitRatio;

  String? get primaryNotebookId {
    if (_openNotebookIds.isEmpty || _activeTabIndex >= _openNotebookIds.length) {
      return null;
    }
    return _openNotebookIds[_activeTabIndex];
  }

  void openNotebook(String notebookId) {
    final existingIndex = _openNotebookIds.indexOf(notebookId);
    if (existingIndex != -1) {
      _activeTabIndex = existingIndex;
    } else {
      _openNotebookIds.add(notebookId);
      _activeTabIndex = _openNotebookIds.length - 1;
    }
    notifyListeners();
  }

  void switchTab(int index) {
    if (index >= 0 && index < _openNotebookIds.length) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }

  void closeTab(int index) {
    if (index < 0 || index >= _openNotebookIds.length) return;

    final closedId = _openNotebookIds[index];
    _openNotebookIds.removeAt(index);

    if (_secondaryNotebookId == closedId) {
      _secondaryNotebookId = null;
      _isSplitScreen = false;
    }

    if (_openNotebookIds.isEmpty) {
      _activeTabIndex = 0;
      _isSplitScreen = false;
    } else if (_activeTabIndex >= _openNotebookIds.length) {
      _activeTabIndex = _openNotebookIds.length - 1;
    }
    notifyListeners();
  }

  void toggleSplitScreen(String? secondaryId) {
    if (_isSplitScreen) {
      _isSplitScreen = false;
      _secondaryNotebookId = null;
    } else {
      if (secondaryId != null && secondaryId != primaryNotebookId) {
        _secondaryNotebookId = secondaryId;
        _isSplitScreen = true;
      } else if (_openNotebookIds.length > 1) {
        // Automatically choose another open tab for the second half of the screen
        final other = _openNotebookIds.firstWhere((id) => id != primaryNotebookId);
        _secondaryNotebookId = other;
        _isSplitScreen = true;
      } else {
        // Duplicate current view for split reference
        _secondaryNotebookId = primaryNotebookId;
        _isSplitScreen = true;
      }
    }
    notifyListeners();
  }

  void setSplitRatio(double ratio) {
    _splitRatio = ratio.clamp(0.2, 0.8);
    notifyListeners();
  }
}
