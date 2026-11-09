class MonthlyBudgetModel {
  final String id;
  final String? userId;
  final String categoryId;
  final String monthYear; // Format: "MM-yyyy"
  final double budgetedAmount;
  final double rolloverAmount;
  final double spentAmount;

  MonthlyBudgetModel({
    required this.id,
    this.userId,
    required this.categoryId,
    required this.monthYear,
    required this.budgetedAmount,
    required this.rolloverAmount,
    required this.spentAmount,
  });

  factory MonthlyBudgetModel.fromMap(Map<String, dynamic> map) {
    return MonthlyBudgetModel(
      id: map['\$id'] ?? map['id'] ?? '',
      userId: map['userId'] ?? map['\$userId'],
      categoryId: map['categoryId'] ??
          (map['categories'] is Map
              ? map['categories']['\$id']
              : (map['categories'] ?? '')) ??
          '',
      monthYear: map['monthYear'] ?? '',
      budgetedAmount: (map['budgetedAmount'] ?? 0).toDouble(),
      rolloverAmount: (map['rolloverAmount'] ?? 0).toDouble(),
      spentAmount: (map['spentAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'categoryId': categoryId,
      'monthYear': monthYear,
      'budgetedAmount': budgetedAmount,
      'rolloverAmount': rolloverAmount,
      'spentAmount': spentAmount,
    };
    if (userId != null && userId!.isNotEmpty) {
      map['userId'] = userId;
    }
    return map;
  }

  MonthlyBudgetModel copyWith({
    String? id,
    String? userId,
    String? categoryId,
    String? monthYear,
    double? budgetedAmount,
    double? rolloverAmount,
    double? spentAmount,
  }) {
    return MonthlyBudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      monthYear: monthYear ?? this.monthYear,
      budgetedAmount: budgetedAmount ?? this.budgetedAmount,
      rolloverAmount: rolloverAmount ?? this.rolloverAmount,
      spentAmount: spentAmount ?? this.spentAmount,
    );
  }
}
