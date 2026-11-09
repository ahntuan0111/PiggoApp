class CategoryTypeModel {
  final String id;
  final String? userId;
  final String name;
  final int priority;

  CategoryTypeModel({
    required this.id,
    this.userId,
    required this.name,
    this.priority = 0,
  });

  factory CategoryTypeModel.fromMap(Map<String, dynamic> map) {
    return CategoryTypeModel(
      id: map['\$id'] ?? map['id'] ?? '',
      userId: map['userId'] ?? map['\$userId'],
      name: map['name'] ?? '',
      priority: map['priority'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'priority': priority,
    };
    if (userId != null && userId!.isNotEmpty) {
      map['userId'] = userId;
    }
    return map;
  }

  CategoryTypeModel copyWith({
    String? id,
    String? userId,
    String? name,
    int? priority,
  }) {
    return CategoryTypeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      priority: priority ?? this.priority,
    );
  }
}
