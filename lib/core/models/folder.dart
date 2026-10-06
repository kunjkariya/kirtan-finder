/// Folder model for grouping and organizing favourite kirtans.
class Folder {
  final int id;
  final String name;
  final int sortOrder;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int kirtanCount;

  const Folder({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.isSystem = false,
    required this.createdAt,
    required this.updatedAt,
    this.kirtanCount = 0,
  });

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int,
      name: map['name'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      isSystem: (map['is_system'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((map['created_at'] as int? ?? 0) * 1000),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        ((map['updated_at'] as int? ?? 0) * 1000),
      ),
      kirtanCount: map['kirtan_count'] as int? ?? 0,
    );
  }

  Folder copyWith({
    int? id,
    String? name,
    int? sortOrder,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? kirtanCount,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kirtanCount: kirtanCount ?? this.kirtanCount,
    );
  }
}
