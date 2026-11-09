class MonthlySummaryModel {
  final String id;
  final String? userId;
  final String monthYear;
  final double totalIncome;
  final double totalExpense;
  final double unallocatedBalance;

  MonthlySummaryModel({
    required this.id,
    this.userId,
    required this.monthYear,
    required this.totalIncome,
    required this.totalExpense,
    required this.unallocatedBalance,
  });

  factory MonthlySummaryModel.fromMap(Map<String, dynamic> map) {
    return MonthlySummaryModel(
      id: map['\$id'] ?? map['id'] ?? '',
      userId: map['userId'] ?? map['\$userId'],
      monthYear: map['monthYear'] ?? '',
      totalIncome: (map['totalIncome'] ?? 0).toDouble(),
      totalExpense: (map['totalExpense'] ?? 0).toDouble(),
      unallocatedBalance: (map['unallocatedBalance'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'monthYear': monthYear,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'unallocatedBalance': unallocatedBalance,
    };
    if (userId != null && userId!.isNotEmpty) {
      map['userId'] = userId;
    }
    return map;
  }

  MonthlySummaryModel copyWith({
    String? id,
    String? userId,
    String? monthYear,
    double? totalIncome,
    double? totalExpense,
    double? unallocatedBalance,
  }) {
    return MonthlySummaryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      monthYear: monthYear ?? this.monthYear,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      unallocatedBalance: unallocatedBalance ?? this.unallocatedBalance,
    );
  }
}
