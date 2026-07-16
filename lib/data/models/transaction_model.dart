class TransactionModel {
  final String id;
  final String walletId;
  final String categoryId;
  final double amount;
  final String type; // 'EXPENSE' or 'INCOME'
  final DateTime transactionDate;
  final String status;
  final String? note; // Denormalized field for search

  TransactionModel({
    required this.id,
    required this.walletId,
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
      walletId: map['walletId'] ?? '',
      categoryId: map['categoryId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      type: map['type'] ?? 'EXPENSE',
      transactionDate: map['transactionDate'] != null
          ? DateTime.parse(map['transactionDate'])
          : DateTime.now(),
      status: map['status'] ?? 'COMPLETED',
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'wallets': walletId, // Sửa theo tên Relationship trên Appwrite
      'amount': amount,
      'type': type,
      'transactionDate': transactionDate.toIso8601String(),
      'status': status,
    };
    if (categoryId.isNotEmpty) {
      map['categories'] = categoryId;
    }
    return map;
  }
}
