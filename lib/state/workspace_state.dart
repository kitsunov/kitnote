import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkspaceState extends ChangeNotifier {
  static const String _prefsOpenTabsKey = 'workspace_open_notebooks';
  static const String _prefsActiveTabKey = 'workspace_active_tab';

  final List<String> _openNotebookIds = [];
  int _activeTabIndex = 0;

  // Split-screen state
  bool _isSplitScreen = false;
  String? _secondaryNotebookId;
  double _splitRatio = 0.5; // 50/50 default

  WorkspaceState() {
    restoreSession();
  }

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

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList(_prefsOpenTabsKey);
      final savedActive = prefs.getInt(_prefsActiveTabKey) ?? 0;
      if (savedIds != null && savedIds.isNotEmpty && _openNotebookIds.isEmpty) {
        _openNotebookIds.addAll(savedIds);
        _activeTabIndex = savedActive.clamp(0, _openNotebookIds.length - 1);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsOpenTabsKey, _openNotebookIds);
      await prefs.setInt(_prefsActiveTabKey, _activeTabIndex);
    } catch (_) {}
  }

  void openNotebook(String notebookId) {
    final existingIndex = _openNotebookIds.indexOf(notebookId);
    if (existingIndex != -1) {
      _activeTabIndex = existingIndex;
    } else {
      _openNotebookIds.add(notebookId);
      _activeTabIndex = _openNotebookIds.length - 1;
    }
    _persistSession();
    notifyListeners();
  }

  void switchTab(int index) {
    if (index >= 0 && index < _openNotebookIds.length) {
      _activeTabIndex = index;
      _persistSession();
      notifyListeners();
    }
  }

  void closeTab(int index) {
    if (index < 0 || index >= _openNotebookIds.length) return;

    final currentActiveId = primaryNotebookId;
    final closedId = _openNotebookIds[index];
    _openNotebookIds.removeAt(index);

    if (_secondaryNotebookId == closedId) {
      _secondaryNotebookId = null;
      _isSplitScreen = false;
    }

    if (_openNotebookIds.isEmpty) {
      _activeTabIndex = 0;
      _isSplitScreen = false;
    } else {
      if (closedId == currentActiveId) {
        // If we closed the active tab, switch to adjacent tab
        if (index >= _openNotebookIds.length) {
          _activeTabIndex = _openNotebookIds.length - 1;
        } else {
          _activeTabIndex = index;
        }
      } else if (currentActiveId != null) {
        // Keep the same active notebook selected
        final newActiveIndex = _openNotebookIds.indexOf(currentActiveId);
        _activeTabIndex = newActiveIndex != -1 ? newActiveIndex : 0;
      }
    }
    _persistSession();
    notifyListeners();
  }

  void closeNotebook(String notebookId) {
    while (_openNotebookIds.contains(notebookId)) {
      final index = _openNotebookIds.indexOf(notebookId);
      closeTab(index);
    }
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
        final other = _openNotebookIds.firstWhere(
          (id) => id != primaryNotebookId,
          orElse: () => primaryNotebookId ?? (_openNotebookIds.isNotEmpty ? _openNotebookIds.first : ''),
        );
        _secondaryNotebookId = other.isNotEmpty ? other : primaryNotebookId;
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

  void setSecondaryNotebook(String notebookId) {
    _secondaryNotebookId = notebookId;
    _isSplitScreen = true;
    notifyListeners();
  }
}
