class CategoryModel {
  final String id;
  final String categoryTypeId;
  final String name;
  final String color;
  final String iconName;
  final double defaultBudget;
  
  CategoryModel({
    required this.id,
    required this.categoryTypeId,
    required this.name,
    required this.color,
    required this.iconName,
    this.defaultBudget = 0.0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['\$id'] ?? '',
      categoryTypeId: map['categoryType'] is Map 
          ? map['categoryType']['\$id'] 
          : (map['categoryType'] ?? map['categoryTypeId'] ?? ''),
      name: map['name'] ?? '',
      color: map['color'] ?? '',
      iconName: map['iconName'] ?? '',
      defaultBudget: (map['defaultBudget'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryType': categoryTypeId,
      'name': name,
      'color': color,
      'iconName': iconName,
      'defaultBudget': defaultBudget,
    };
  }
}
