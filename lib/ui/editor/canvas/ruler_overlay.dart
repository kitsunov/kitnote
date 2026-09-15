import 'dart:math' as math;
import 'package:flutter/material.dart';

class RulerOverlay extends StatelessWidget {
  final Offset position;
  final double angle; // In radians
  final Function(Offset delta, double angleDelta) onTransform;
  final VoidCallback onClose;

  const RulerOverlay({
    super.key,
    required this.position,
    required this.angle,
    required this.onTransform,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const rulerWidth = 500.0;
    const rulerHeight = 80.0;

    return Positioned(
      left: position.dx - rulerWidth / 2,
      top: position.dy - rulerHeight / 2,
      child: Transform.rotate(
        angle: angle,
        child: GestureDetector(
          onPanUpdate: (details) {
            onTransform(details.delta, 0.0);
          },
          child: Container(
            width: rulerWidth,
            height: rulerHeight,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Top scale marks (cm / mm)
                CustomPaint(
                  size: const Size(rulerWidth, rulerHeight),
                  painter: _RulerTicksPainter(),
                ),

                // Center handle with degree readout
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rotate handle Left
                      IconButton(
                        icon: const Icon(Icons.rotate_left, size: 20, color: Colors.blueGrey),
                        onPressed: () => onTransform(Offset.zero, -math.pi / 36), // -5 deg
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          '${((angle * 180 / math.pi) % 360).round()}°',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                      // Rotate handle Right
                      IconButton(
                        icon: const Icon(Icons.rotate_right, size: 20, color: Colors.blueGrey),
                        onPressed: () => onTransform(Offset.zero, math.pi / 36), // +5 deg
                      ),
                    ],
                  ),
                ),

                // Close button
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RulerTicksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = Colors.black45
      ..strokeWidth = 1.0;

    const cmInterval = 28.35; // Approx 1 cm in points at standard DPI

    int cmIndex = 0;
    for (double x = 20; x < size.width - 20; x += cmInterval / 10) {
      final isCm = (cmIndex % 10) == 0;
      final isHalfCm = (cmIndex % 5) == 0;

      final tickLength = isCm ? 18.0 : (isHalfCm ? 12.0 : 7.0);

      canvas.drawLine(Offset(x, 0), Offset(x, tickLength), tickPaint);

      if (isCm) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${cmIndex ~/ 10}',
            style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, tickLength + 2));
      }
      cmIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
