class TransactionModel {
  final String id;
  final String categoryId;
  final double amount;
  final String type; // 'EXPENSE' or 'INCOME'
  final DateTime transactionDate;
  final String status;
  final String? note; // Denormalized field for search

  TransactionModel({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.transactionDate,
    required this.status,
    this.note,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['\$id'] ?? map['id'] ?? '',
      categoryId: _extractId(map['categories']) ?? map['categoryId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      type: map['type'] ?? 'EXPENSE',
      transactionDate: map['transactionDate'] != null
          ? DateTime.tryParse(map['transactionDate'])?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      status: map['status'] ?? 'COMPLETED',
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'amount': amount,
      'type': type,
      'transactionDate': transactionDate.toUtc().toIso8601String(),
      'status': status,
    };
    if (categoryId.isNotEmpty) {
      map['categories'] = categoryId;
    }
    return map;
  }

  static String? _extractId(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return value['\$id'] ?? value['id'];
    return null;
  }
}
