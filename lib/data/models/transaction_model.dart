class TransactionModel {
  final String id;
  final String categoryId;
  final double amount;
  final String type; // 'EXPENSE' or 'INCOME'
  final DateTime transactionDate;
  final String status;
  final String? note; // Denormalized field for search
  final DateTime? updatedAt;

  TransactionModel({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.transactionDate,
    required this.status,
    this.note,
    this.updatedAt,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['\$id'] ?? map['id'] ?? '',
      categoryId: map['categoryId'] ?? _extractId(map['categories']) ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      type: map['type'] ?? 'EXPENSE',
      transactionDate: map['transactionDate'] != null
          ? DateTime.tryParse(map['transactionDate'])?.toLocal() ??
                DateTime.now()
          : DateTime.now(),
      status: map['status'] ?? 'COMPLETED',
      note: map['note'],
      updatedAt: map['\$updatedAt'] != null
          ? DateTime.tryParse(map['\$updatedAt'])?.toLocal()
          : map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'amount': amount,
      'type': type,
      'transactionDate': transactionDate.toUtc().toIso8601String(),
      'status': status,
      'note': note ?? '',
    };
    if (categoryId.isNotEmpty) {
      map['categoryId'] = categoryId;
    }
    if (updatedAt != null) {
      map['updatedAt'] = updatedAt!.toUtc().toIso8601String();
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
