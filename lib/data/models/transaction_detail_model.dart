class TransactionDetailModel {
  final String id;
  final String transactionId;
  final String note;
  final List<String> receiptFileIds;
  final String rawInputText;
  final double confidenceScore;

  TransactionDetailModel({
    required this.id,
    required this.transactionId,
    required this.note,
    required this.receiptFileIds,
    required this.rawInputText,
    required this.confidenceScore,
  });

  factory TransactionDetailModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedFileIds = [];
    final receiptStr = map['receiptFileId'] as String?;
    if (receiptStr != null && receiptStr.isNotEmpty) {
      parsedFileIds = receiptStr.split(',');
    }

    return TransactionDetailModel(
      id: map['\$id'] ?? map['id'] ?? '',
      transactionId: map['transactionId'] ?? '',
      note: map['note'] ?? '',
      receiptFileIds: parsedFileIds,
      rawInputText: map['rawInputText'] ?? '',
      confidenceScore: (map['confidenceScore'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transactions':
          transactionId, // Tên relationship thường là 'transactions'
      'note': note,
      'receiptFileId': receiptFileIds.join(','),
      'rawInputText': rawInputText,
      'confidenceScore': confidenceScore,
    };
  }
}
