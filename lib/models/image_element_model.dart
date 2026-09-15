import 'dart:typed_data';
import 'dart:ui';

class ImageElementModel {
  final String id;
  final String? localPath;
  final Uint8List? rawBytes;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation; // in radians

  const ImageElementModel({
    required this.id,
    this.localPath,
    this.rawBytes,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0.0,
  });

  Rect get boundingBox => Rect.fromLTWH(x, y, width, height);

  ImageElementModel copyWith({
    String? id,
    String? localPath,
    Uint8List? rawBytes,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
  }) {
    return ImageElementModel(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      rawBytes: rawBytes ?? this.rawBytes,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
    );
  }

  ImageElementModel translate(double dx, double dy) {
    return copyWith(x: x + dx, y: y + dy);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': localPath,
    'x': x,
    'y': y,
    'w': width,
    'h': height,
    'rot': rotation,
  };

  factory ImageElementModel.fromJson(Map<String, dynamic> json) =>
      ImageElementModel(
        id: json['id'] as String,
        localPath: json['path'] as String?,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['w'] as num).toDouble(),
        height: (json['h'] as num).toDouble(),
        rotation: (json['rot'] as num?)?.toDouble() ?? 0.0,
      );
}
