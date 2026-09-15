import 'dart:ui';

class FolderModel {
  final String id;
  final String name;
  final String? parentId;
  final int colorValue;
  final DateTime createdAt;

  const FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    this.colorValue = 0xFF64748B,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentId,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pId': parentId,
    'c': colorValue,
    'cAt': createdAt.toIso8601String(),
  };

  factory FolderModel.fromJson(Map<String, dynamic> json) => FolderModel(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Новая папка',
    parentId: json['pId'] as String?,
    colorValue: json['c'] as int? ?? 0xFF64748B,
    createdAt: json['cAt'] != null
        ? DateTime.tryParse(json['cAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}
