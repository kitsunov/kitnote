import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/engine/palm_rejection_manager.dart';

void main() {
  group('PalmRejectionManager Tests', () {
    test('StylusOnly mode accepts stylus pointers and rejects single touch pointers', () {
      final manager = PalmRejectionManager(mode: PalmRejectionMode.stylusOnly);

      const stylusDown = PointerDownEvent(
        kind: PointerDeviceKind.stylus,
        position: Offset(100, 200),
      );
      expect(manager.shouldAcceptPointerForInking(stylusDown), isTrue);

      const touchDown = PointerDownEvent(
        kind: PointerDeviceKind.touch,
        position: Offset(150, 250),
      );
      // In stylusOnly mode, touch touches are filtered out to prevent palm marks!
      expect(manager.shouldAcceptPointerForInking(touchDown), isFalse);
    });

    test('StylusAndTouch mode accepts single touch pointers but rejects multi-finger palm contacts', () {
      final manager = PalmRejectionManager(mode: PalmRejectionMode.stylusAndTouch);

      const firstTouch = PointerDownEvent(
        kind: PointerDeviceKind.touch,
        position: Offset(50, 50),
      );
      expect(manager.shouldAcceptPointerForInking(firstTouch), isTrue);

      const secondTouch = PointerDownEvent(
        kind: PointerDeviceKind.touch,
        position: Offset(100, 100),
      );
      // Multi-touch (palm or 2 fingers) should be rejected from inking!
      expect(manager.shouldAcceptPointerForInking(secondTouch), isFalse);
    });
  });
}
