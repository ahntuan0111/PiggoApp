class CategoryTypeModel {
  final String id;
  final String ownerId;
  final String name;
  final int priority;

  CategoryTypeModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.priority = 0,
  });

  factory CategoryTypeModel.fromMap(Map<String, dynamic> map) {
    return CategoryTypeModel(
      id: map['\$id'] ?? map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      priority: map['priority'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'priority': priority,
    };
  }
}
