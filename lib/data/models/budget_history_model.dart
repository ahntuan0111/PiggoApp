class BudgetHistoryModel {
  final String id;
  final String monthYear;
  final double totalInflow;
  final double totalOutflow;
  final String rolloverMethod;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BudgetHistoryModel({
    required this.id,
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
    return {
      'id': id,
      'monthYear': monthYear,
      'totalInflow': totalInflow,
      'totalOutflow': totalOutflow,
      'rolloverMethod': rolloverMethod,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
