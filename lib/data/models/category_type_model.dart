class CategoryTypeModel {
  final String id;
  final String name;
  final int priority;

  CategoryTypeModel({
    required this.id,
    required this.name,
    this.priority = 0,
  });

  factory CategoryTypeModel.fromMap(Map<String, dynamic> map) {
    return CategoryTypeModel(
      id: map['\$id'] ?? map['id'] ?? '',
      name: map['name'] ?? '',
      priority: map['priority'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'priority': priority};
  }
}
