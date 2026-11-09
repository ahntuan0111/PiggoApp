class TransactionModel {
  final String id;
  final String? userId;
  final String categoryId;
  final double amount;
  final String type; // 'EXPENSE' or 'INCOME'
  final DateTime transactionDate;
  final String status;
  final String? note; // Denormalized field for search
  final DateTime? updatedAt;

  TransactionModel({
    required this.id,
    this.userId,
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
      userId: map['userId'] ?? map['\$userId'],
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
    if (userId != null && userId!.isNotEmpty) {
      map['userId'] = userId;
    }
    if (categoryId.isNotEmpty) {
      map['categoryId'] = categoryId;
    }
    if (updatedAt != null) {
      map['updatedAt'] = updatedAt!.toUtc().toIso8601String();
    }
    return map;
  }

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? categoryId,
    double? amount,
    String? type,
    DateTime? transactionDate,
    String? status,
    String? note,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      transactionDate: transactionDate ?? this.transactionDate,
      status: status ?? this.status,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? _extractId(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return value['\$id'] ?? value['id'];
    return null;
  }
}
