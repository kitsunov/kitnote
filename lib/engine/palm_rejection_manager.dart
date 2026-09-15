import 'package:flutter/gestures.dart';

enum PalmRejectionMode {
  stylusOnly, // Only active stylus draws. Fingers & palm do NOT draw.
  stylusAndTouch, // Both stylus and finger can draw.
}

class PalmRejectionManager {
  PalmRejectionMode mode;
  bool _isStylusActive = false;
  int _activeTouchCount = 0;

  PalmRejectionManager({this.mode = PalmRejectionMode.stylusOnly});

  bool get isStylusActive => _isStylusActive;
  int get activeTouchCount => _activeTouchCount;

  /// Determines if an incoming pointer down event should be accepted for drawing
  bool shouldAcceptPointerForInking(PointerDownEvent event) {
    final kind = event.kind;

    if (kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus) {
      _isStylusActive = true;
      return true;
    }

    if (kind == PointerDeviceKind.touch) {
      _activeTouchCount++;

      // When stylus-only mode is active, reject single touches from drawing
      if (mode == PalmRejectionMode.stylusOnly) {
        return false;
      }

      // If more than 1 finger is down (e.g. 2-finger zoom/pan or palm contact), reject inking!
      if (_activeTouchCount > 1) {
        return false;
      }

      // If stylus was recently drawing, reject palm touches
      if (_isStylusActive) {
        return false;
      }

      return true;
    }

    // Mouse / trackpad allowed
    if (kind == PointerDeviceKind.mouse) {
      return true;
    }

    return false;
  }

  /// Called on pointer up or cancel
  void handlePointerUp(PointerUpEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      if (_activeTouchCount > 0) _activeTouchCount--;
    } else if (event.kind == PointerDeviceKind.stylus ||
               event.kind == PointerDeviceKind.invertedStylus) {
      _isStylusActive = false;
    }
  }

  void handlePointerCancel(PointerCancelEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      if (_activeTouchCount > 0) _activeTouchCount--;
    } else if (event.kind == PointerDeviceKind.stylus ||
               event.kind == PointerDeviceKind.invertedStylus) {
      _isStylusActive = false;
    }
  }

  void reset() {
    _isStylusActive = false;
    _activeTouchCount = 0;
  }
}
