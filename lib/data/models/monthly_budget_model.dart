class MonthlyBudgetModel {
  final String id;
  final String categoryId;
  final String monthYear; // Format: "MM-yyyy"
  final double budgetedAmount;
  final double rolloverAmount;
  final double spentAmount;

  MonthlyBudgetModel({
    required this.id,
    required this.categoryId,
    required this.monthYear,
    required this.budgetedAmount,
    required this.rolloverAmount,
    required this.spentAmount,
  });

  factory MonthlyBudgetModel.fromMap(Map<String, dynamic> map) {
    return MonthlyBudgetModel(
      id: map['\$id'] ?? map['id'] ?? '',
      categoryId: map['categories'] is Map
          ? map['categories']['\$id']
          : (map['categories'] ?? map['categoryId'] ?? ''),
      monthYear: map['monthYear'] ?? '',
      budgetedAmount: (map['budgetedAmount'] ?? 0).toDouble(),
      rolloverAmount: (map['rolloverAmount'] ?? 0).toDouble(),
      spentAmount: (map['spentAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categories': categoryId,
      'monthYear': monthYear,
      'budgetedAmount': budgetedAmount,
      'rolloverAmount': rolloverAmount,
      'spentAmount': spentAmount,
    };
  }
}
