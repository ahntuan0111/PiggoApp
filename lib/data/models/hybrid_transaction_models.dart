/// Các mô hình dữ liệu phục vụ kiến trúc Hybrid Router (Dart + On-Device AI)
library;

/// Loại đường dẫn phân luồng xử lý
enum TransactionRouteType {
  /// Nhánh nhanh: Dùng Dart Rule-Based (< 1ms, 0 RAM) cho câu đơn giản rõ ràng
  fastPathDart,

  /// Nhánh thông minh: Dùng On-Device AI cho câu nhiều số, đa giao dịch hoặc mơ hồ
  smartPathAi,
}

/// Quyết định định tuyến của TransactionRouter
class TransactionRouteDecision {
  final TransactionRouteType routeType;
  final String rawText;
  final List<String> candidateTokens;
  final String reason;

  const TransactionRouteDecision({
    required this.routeType,
    required this.rawText,
    required this.candidateTokens,
    required this.reason,
  });

  bool get isFastPath => routeType == TransactionRouteType.fastPathDart;
  bool get isSmartPath => routeType == TransactionRouteType.smartPathAi;

  @override
  String toString() =>
      'TransactionRouteDecision(type: $routeType, reason: $reason, tokens: $candidateTokens)';
}

/// Dữ liệu thô do mô hình On-Device AI trích xuất (JSON Schema)
class RawAiTransactionItem {
  final String amountText;
  final String note;
  final String? categoryHint;
  final String type; // 'outflow' | 'inflow'

  const RawAiTransactionItem({
    required this.amountText,
    required this.note,
    this.categoryHint,
    this.type = 'outflow',
  });

  factory RawAiTransactionItem.fromJson(Map<String, dynamic> json) {
    return RawAiTransactionItem(
      amountText: json['amount_text']?.toString().trim() ?? '',
      note: json['note']?.toString().trim() ?? '',
      categoryHint: json['category_hint']?.toString().trim(),
      type: (json['type']?.toString().toLowerCase().trim() == 'inflow')
          ? 'inflow'
          : 'outflow',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount_text': amountText,
      'note': note,
      'category_hint': categoryHint,
      'type': type,
    };
  }

  RawAiTransactionItem copyWith({
    String? amountText,
    String? note,
    String? categoryHint,
    String? type,
  }) {
    return RawAiTransactionItem(
      amountText: amountText ?? this.amountText,
      note: note ?? this.note,
      categoryHint: categoryHint ?? this.categoryHint,
      type: type ?? this.type,
    );
  }
}

