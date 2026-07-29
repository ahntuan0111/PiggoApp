class MonthlySummaryModel {
  final String id;
  final String monthYear;
  final double totalIncome;
  final double totalExpense;
  final double unallocatedBalance;

  MonthlySummaryModel({
    required this.id,
    required this.monthYear,
    required this.totalIncome,
    required this.totalExpense,
    required this.unallocatedBalance,
  });

  factory MonthlySummaryModel.fromMap(Map<String, dynamic> map) {
    return MonthlySummaryModel(
      id: map['\$id'] ?? map['id'] ?? '',
      monthYear: map['monthYear'] ?? '',
      totalIncome: (map['totalIncome'] ?? 0).toDouble(),
      totalExpense: (map['totalExpense'] ?? 0).toDouble(),
      unallocatedBalance: (map['unallocatedBalance'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monthYear': monthYear,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'unallocatedBalance': unallocatedBalance,
    };
  }
}
