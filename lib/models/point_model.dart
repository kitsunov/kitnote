import 'dart:ui';

class Point2D {
  final double x;
  final double y;
  final double pressure;
  final int timestamp;

  const Point2D({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    required this.timestamp,
  });

  Offset toOffset() => Offset(x, y);

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'p': pressure,
    't': timestamp,
  };

  factory Point2D.fromJson(Map<String, dynamic> json) => Point2D(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    pressure: (json['p'] as num?)?.toDouble() ?? 1.0,
    timestamp: json['t'] as int? ?? 0,
  );

  Point2D translate(double dx, double dy) => Point2D(
    x: x + dx,
    y: y + dy,
    pressure: pressure,
    timestamp: timestamp,
  );
}
