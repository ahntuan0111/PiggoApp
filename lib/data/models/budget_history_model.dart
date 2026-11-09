class BudgetHistoryModel {
  final String id;
  final String? userId;
  final String monthYear;
  final double totalInflow;
  final double totalOutflow;
  final String rolloverMethod;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BudgetHistoryModel({
    required this.id,
    this.userId,
    required this.monthYear,
    this.totalInflow = 0.0,
    this.totalOutflow = 0.0,
    this.rolloverMethod = 'ROLLOVER_ALL',
    this.createdAt,
    this.updatedAt,
  });

  factory BudgetHistoryModel.fromMap(Map<String, dynamic> map) {
    return BudgetHistoryModel(
      id: map['\$id'] ?? map['id'] ?? '',
      userId: map['userId'] ?? map['\$userId'],
      monthYear: map['monthYear'] ?? '',
      totalInflow: (map['totalInflow'] ?? 0).toDouble(),
      totalOutflow: (map['totalOutflow'] ?? 0).toDouble(),
      rolloverMethod: map['rolloverMethod'] ?? 'ROLLOVER_ALL',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'])
          : (map['\$createdAt'] != null ? DateTime.tryParse(map['\$createdAt']) : null),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : (map['\$updatedAt'] != null ? DateTime.tryParse(map['\$updatedAt']) : null),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'monthYear': monthYear,
      'totalInflow': totalInflow,
      'totalOutflow': totalOutflow,
      'rolloverMethod': rolloverMethod,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
    if (userId != null && userId!.isNotEmpty) {
      map['userId'] = userId;
    }
    return map;
  }

  BudgetHistoryModel copyWith({
    String? id,
    String? userId,
    String? monthYear,
    double? totalInflow,
    double? totalOutflow,
    String? rolloverMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetHistoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      monthYear: monthYear ?? this.monthYear,
      totalInflow: totalInflow ?? this.totalInflow,
      totalOutflow: totalOutflow ?? this.totalOutflow,
      rolloverMethod: rolloverMethod ?? this.rolloverMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
