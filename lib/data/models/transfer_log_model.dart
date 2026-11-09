import 'dart:convert';

class TransferLogModel {
  final String id;
  final String? userId;
  final double amount;
  final String fromCategoryId;
  final String toCategoryId;
  final String? note;
  final DateTime createdAt;

  TransferLogModel({
    required this.id,
    this.userId,
    required this.amount,
    required this.fromCategoryId,
    required this.toCategoryId,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'amount': amount,
      'fromCategoryId': fromCategoryId,
      'toCategoryId': toCategoryId,
      'note': note,
    };
    if (userId != null && userId!.isNotEmpty) {
      map['userId'] = userId;
    }
    return map;
  }

  factory TransferLogModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return TransferLogModel(
      id: docId ?? map['\$id'] ?? map['id'] ?? '',
      userId: map['userId'] ?? map['\$userId'],
      amount: (map['amount'] ?? 0).toDouble(),
      fromCategoryId: map['fromCategoryId'] ?? '',
      toCategoryId: map['toCategoryId'] ?? '',
      note: map['note'],
      createdAt:
          DateTime.tryParse(
            map['\$createdAt'] ?? map['createdAt'] ?? '',
          )?.toLocal() ??
          DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory TransferLogModel.fromJson(String source) =>
      TransferLogModel.fromMap(json.decode(source));

  TransferLogModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? fromCategoryId,
    String? toCategoryId,
    String? note,
    DateTime? createdAt,
  }) {
    return TransferLogModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      fromCategoryId: fromCategoryId ?? this.fromCategoryId,
      toCategoryId: toCategoryId ?? this.toCategoryId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
