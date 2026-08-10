import 'dart:convert';

class TransferLogModel {
  final String id;
  final double amount;
  final String fromCategoryId;
  final String toCategoryId;
  final String? note;
  final DateTime createdAt;

  TransferLogModel({
    required this.id,
    required this.amount,
    required this.fromCategoryId,
    required this.toCategoryId,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'fromCategoryId': fromCategoryId,
      'toCategoryId': toCategoryId,
      'note': note,
    };
  }

  factory TransferLogModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return TransferLogModel(
      id: docId ?? map['\$id'] ?? '',
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
}
