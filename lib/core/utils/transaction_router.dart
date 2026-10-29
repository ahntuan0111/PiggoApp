import 'package:appintern/data/models/hybrid_transaction_models.dart';
import 'package:appintern/core/utils/local_rule_based_transaction_parser.dart';

/// Bộ định tuyến thông minh (Transaction Router)
/// Phân loại câu nói/văn bản người dùng thành:
///   - Fast Path (Dart Engine): < 1ms, 0 RAM, 0 Token cho các câu đơn giản rõ ràng.
///   - Smart Path (AI On-Device): Dành cho các câu phức tạp (nhiều mốc tiền, nhiều giao dịch, số lượng hàng hóa lẫn số tiền, xung đột thu chi).
class TransactionRouter {
  /// Danh sách từ khóa đơn vị số lượng / danh từ đếm phổ biến
  static final List<String> _quantityUnitKeywords = [
    'cái',
    'cai',
    'chiếc',
    'chiec',
    'bát',
    'bat',
    'tô',
    'to',
    'ly',
    'cốc',
    'coc',
    'chén',
    'chen',
    'đĩa',
    'dia',
    'phần',
    'phan',
    'suất',
    'suat',
    'hộp',
    'hop',
    'bịch',
    'bich',
    'gói',
    'goi',
    'lon',
    'chai',
    'cân',
    'can',
    'kg',
    'kí',
    'ki',
    'vé',
    've',
    'áo',
    'ao',
    'quần',
    'quan',
    'đôi',
    'doi',
    'cuốn',
    'cuon',
    'quyển',
    'quyen',
  ];

  static final List<String> _incomeIndicators = [
    'lương',
    'luong',
    'thưởng',
    'thuong',
    'nhận',
    'nhan',
    'đòi được',
    'doi duoc',
    'hoàn tiền',
    'hoan tien',
    'tiền về',
    'tien ve',
    'lãi',
    'lai',
    'bán',
    'ban',
    'được cho',
    'duoc cho',
  ];

  static final List<String> _expenseIndicators = [
    'mua',
    'đổ xăng',
    'do xang',
    'ăn',
    'an',
    'uống',
    'uong',
    'trả',
    'tra',
    'chi',
    'tiêu',
    'tieu',
    'đóng tiền',
    'dong tien',
    'thuê',
    'thue',
    'nạp',
    'nap',
  ];

  /// Quyết định định tuyến xử lý cho đoạn văn bản đầu vào
  static TransactionRouteDecision route(String text) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return TransactionRouteDecision(
        routeType: TransactionRouteType.fastPathDart,
        rawText: cleanText,
        candidateTokens: const [],
        reason: 'Văn bản rỗng, mặc định Dart xử lý',
      );
    }

    final lowerText = cleanText.toLowerCase();
    final normText = LocalRuleBasedTransactionParser.removeAccents(lowerText);

    // 1. Quét tìm tất cả các mốc tiền bằng moneyRegex
    final allMatches = LocalRuleBasedTransactionParser.moneyRegex
        .allMatches(cleanText)
        .where((m) {
          // Bỏ qua số âm (vd: "-50k")
          if (m.start > 0 && cleanText[m.start - 1] == '-') return false;
          return true;
        })
        .toList();

    final candidateTokens = allMatches.map((m) => m.group(0)!.trim()).toList();

    // 2. Trường hợp không có mốc tiền nào -> Fast Path (Dart xử lý để giữ note)
    if (allMatches.isEmpty) {
      return TransactionRouteDecision(
        routeType: TransactionRouteType.fastPathDart,
        rawText: cleanText,
        candidateTokens: const [],
        reason: 'Không tìm thấy mốc tiền, chuyển Dart xử lý',
      );
    }

    // 3. Trường hợp có từ 2 mốc số tiền/số trần trở lên
    // Ví dụ: "do xang 50 an bun bo 55", "mua 2 ao 200k", "thue nha 3 trieu tien dien 500k"
    if (allMatches.length >= 2) {
      final hasQuantityConfusion = _detectQuantityConfusion(cleanText, allMatches);
      final reason = hasQuantityConfusion
          ? 'Phát hiện số lượng kết hợp số tiền (${candidateTokens.join(', ')})'
          : 'Phát hiện nhiều mốc số tiền (${candidateTokens.join(', ')})';

      return TransactionRouteDecision(
        routeType: TransactionRouteType.smartPathAi,
        rawText: cleanText,
        candidateTokens: candidateTokens,
        reason: reason,
      );
    }

    // 4. Trường hợp chỉ có đúng 1 mốc tiền
    // Kiểm tra xem có xung đột đồng thời cả từ khóa Thu nhập và Chi tiêu không
    final hasIncome = _containsAnyKeyword(lowerText, normText, _incomeIndicators);
    final hasExpense = _containsAnyKeyword(lowerText, normText, _expenseIndicators);

    if (hasIncome && hasExpense) {
      return TransactionRouteDecision(
        routeType: TransactionRouteType.smartPathAi,
        rawText: cleanText,
        candidateTokens: candidateTokens,
        reason: 'Xuất hiện đồng thời từ khóa thu và chi gây mơ hồ ý định',
      );
    }

    // 5. Đơn giao dịch với 1 mốc tiền rõ ràng -> Fast Path (Dart Engine < 1ms)
    return TransactionRouteDecision(
      routeType: TransactionRouteType.fastPathDart,
      rawText: cleanText,
      candidateTokens: candidateTokens,
      reason: 'Đơn giao dịch với 1 mốc tiền rõ ràng, không mơ hồ',
    );
  }

  /// Phát hiện số lượng hàng hóa đi liền trước danh từ (vd: "2 áo", "3 ly")
  static bool _detectQuantityConfusion(String text, List<RegExpMatch> matches) {
    for (final match in matches) {
      final unit = match.group(2);
      if (unit == null || unit.isEmpty) {
        final afterText = text.substring(match.end).trim();
        final words = afterText.split(RegExp(r'\s+'));
        if (words.isNotEmpty) {
          final nextWordNorm = LocalRuleBasedTransactionParser.removeAccents(
            words.first.toLowerCase(),
          );
          if (_quantityUnitKeywords.contains(nextWordNorm)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static bool _containsAnyKeyword(
    String lowerText,
    String normText,
    List<String> keywords,
  ) {
    return keywords.any((kw) {
      final pattern = RegExp(
        '(?:^|[^a-zA-Z0-9_à-ỹÀ-ỸđĐ])${RegExp.escape(kw)}(?:[^a-zA-Z0-9_à-ỹÀ-ỸđĐ]|\$)',
        caseSensitive: false,
      );
      return pattern.hasMatch(lowerText) || pattern.hasMatch(normText);
    });
  }
}
