class CategoryModel {
  final String id;
  final String categoryTypeId;
  final String name;
  final String color;
  final String iconName;
  final double defaultBudget;
  double spent; // Thêm trường spent để sửa lỗi UI
  
  double get remaining => defaultBudget - spent; // Getter tính số tiền còn lại

  CategoryModel({
    required this.id,
    required this.categoryTypeId,
    required this.name,
    required this.color,
    required this.iconName,
    this.defaultBudget = 0.0,
    this.spent = 0.0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['\$id'] ?? '',
      categoryTypeId: map['categoryTypes'] is Map
          ? map['categoryTypes']['\$id']
          : (map['categoryTypes'] ?? map['categoryTypeId'] ?? ''),
      name: map['name'] ?? '',
      color: map['color'] ?? '',
      iconName: map['iconName'] ?? '',
      defaultBudget: (map['defaultBudget'] ?? 0).toDouble(),
      spent: (map['spent'] ?? 0).toDouble(), // Parse spent nếu có
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryTypes': categoryTypeId,
      'name': name,
      'color': color,
      'iconName': iconName,
      'defaultBudget': defaultBudget,
    };
  }
}
