class GoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final DateTime? deadline;
  final String categoryId;
  final String status;
  final DateTime? createdAt;

  GoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.deadline,
    required this.categoryId,
    required this.status,
    this.createdAt,
  });

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['\$id'] ?? map['id'] ?? '',
      name: map['name'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0.0).toDouble(),
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'])
          : null,
      categoryId: map['categories'] is Map
          ? (map['categories']['\$id'] ?? '')
          : (map['categories'] ?? ''),
      status: map['status'] ?? 'ACTIVE',
      createdAt: map['\$createdAt'] != null
          ? DateTime.parse(map['\$createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'targetAmount': targetAmount,
      'deadline': deadline?.toIso8601String(),
      'categories': categoryId,
      'status': status,
    };
  }

  GoalModel copyWith({
    String? id,
    String? name,
    double? targetAmount,
    DateTime? deadline,
    String? categoryId,
    String? status,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      deadline: deadline ?? this.deadline, // Giữ null nếu không truyền, hoặc giữ cũ nếu không truyền (cần handle null tường minh, nhưng để tạm thế này)
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
