class GoalModel {
  final String id;
  final String? userId;
  final String name;
  final double targetAmount;
  final double? currentAmount;
  final DateTime? deadline;
  final String categoryId;
  final String status;
  final DateTime? createdAt;

  GoalModel({
    required this.id,
    this.userId,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.deadline,
    required this.categoryId,
    required this.status,
    this.createdAt,
  });

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['\$id'] ?? map['id'] ?? '',
      userId: map['userId'] ?? map['\$userId'],
      name: map['name'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0.0).toDouble(),
      currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0.0,
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'])?.toLocal()
          : null,
      categoryId: map['categoryId'] ??
          (map['categories'] is Map
              ? (map['categories']['\$id'] ?? '')
              : (map['categories'] ?? '')),
      status: map['status'] ?? 'ACTIVE',
      createdAt: map['\$createdAt'] != null
          ? DateTime.tryParse(map['\$createdAt'])?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount ?? 0.0,
      'deadline': deadline?.toUtc().toIso8601String(),
      'categoryId': categoryId,
      'status': status,
    };
    if (userId != null && userId!.isNotEmpty) {
      map['userId'] = userId;
    }
    return map;
  }

  GoalModel copyWith({
    String? id,
    String? userId,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? categoryId,
    String? status,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      categoryId: categoryId ?? this.categoryId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
