class CategoryModel {
  final String id;
  final String? userId;
  final String categoryTypeId;
  final String name;
  final String color;
  final String iconName;
  final double defaultBudget;
  final double? targetAmount;
  final DateTime? deadline;
  final bool isActive;
  double spent; // Thêm trường spent để sửa lỗi UI

  double get remaining => defaultBudget - spent; // Getter tính số tiền còn lại

  CategoryModel({
    required this.id,
    this.userId,
    required this.categoryTypeId,
    required this.name,
    required this.color,
    required this.iconName,
    this.defaultBudget = 0.0,
    this.targetAmount,
    this.deadline,
    this.isActive = true,
    this.spent = 0.0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['\$id'] ?? map['id'] ?? '',
      userId: map['userId'] ?? map['\$userId'],
      categoryTypeId: map['categoryTypeId'] ??
          (map['categoryTypes'] is Map
              ? map['categoryTypes']['\$id']
              : (map['categoryTypes'] ?? '')) ??
          '',
      name: map['name'] ?? '',
      color: map['color'] ?? '',
      iconName: map['iconName'] ?? '',
      defaultBudget: (map['defaultBudget'] ?? 0).toDouble(),
      targetAmount: map['targetAmount'] != null
          ? (map['targetAmount'] as num).toDouble()
          : null,
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'].toString())
          : null,
      isActive: map['isActive'] == null
          ? true
          : (map['isActive'] == 1 ||
                map['isActive'] == true), // Fallback true cho dữ liệu cũ (NULL)
      spent: (map['spent'] ?? 0).toDouble(), // Parse spent nếu có
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'categoryTypeId': categoryTypeId,
      'name': name,
      'color': color,
      'iconName': iconName,
      'defaultBudget': defaultBudget,
      'targetAmount': targetAmount,
      'deadline': deadline?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
    if (userId != null && userId!.isNotEmpty) {
      map['userId'] = userId;
    }
    return map;
  }

  CategoryModel copyWith({
    String? id,
    String? userId,
    String? categoryTypeId,
    String? name,
    String? color,
    String? iconName,
    double? defaultBudget,
    double? targetAmount,
    DateTime? deadline,
    bool? isActive,
    double? spent,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryTypeId: categoryTypeId ?? this.categoryTypeId,
      name: name ?? this.name,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      defaultBudget: defaultBudget ?? this.defaultBudget,
      targetAmount: targetAmount ?? this.targetAmount,
      deadline: deadline ?? this.deadline,
      isActive: isActive ?? this.isActive,
      spent: spent ?? this.spent,
    );
  }
}
