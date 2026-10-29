import 'package:appintern/data/models/hybrid_transaction_models.dart';
import 'package:appintern/core/utils/local_rule_based_transaction_parser.dart';

/// Tầng Thẩm Định Chốt Chặn (Dart Validation Layer)
/// Đóng vai trò Guardrail chống ảo giác cho kết quả từ On-Device AI:
/// 1. Grounding Check: Mốc tiền phải có thật trong câu người dùng, từ chối 100% mốc tiền tự bịa.
/// 2. Deterministic Parsing: Quy đổi số tiền xác định bằng logic Dart (không tin tưởng phép tính của AI).
/// 3. Category Alignment: Chuẩn hóa danh mục theo danh sách của người dùng, để trống nếu không khớp.
/// 4. Type & Date Validation: Đảm bảo loại thu/chi và thời gian luôn hợp lệ.
class DartValidationLayer {
  /// Thẩm định và làm giàu dữ liệu từ kết quả AI
  static List<Map<String, dynamic>> validateAndEnrich({
    required String rawInput,
    required List<RawAiTransactionItem> aiItems,
    required List<String> availableCategories,
    required String currentTime,
  }) {
    if (aiItems.isEmpty) return const [];

    final cleanInput = rawInput.trim();
    final lowerInput = cleanInput.toLowerCase();
    final normInput = LocalRuleBasedTransactionParser.removeAccents(lowerInput);

    // Thời gian mặc định
    DateTime baseDate = DateTime.tryParse(currentTime) ?? DateTime.now();
    if (lowerInput.contains('hôm qua') ||
        normInput.contains('hom qua') ||
        lowerInput.contains('qua')) {
      baseDate = baseDate.subtract(const Duration(days: 1));
    } else if (lowerInput.contains('hôm kia') ||
        normInput.contains('hom kia')) {
      baseDate = baseDate.subtract(const Duration(days: 2));
    }
    final defaultDateIso = baseDate.toUtc().toIso8601String();

    final validatedList = <Map<String, dynamic>>[];

    for (final item in aiItems) {
      final amountToken = item.amountText.trim();
      if (amountToken.isEmpty) continue;

      // 1. Chốt chặn Grounding: Mốc tiền phải xuất hiện trong văn bản gốc
      if (!_isGroundedInText(amountToken, cleanInput)) {
        // AI ảo giác số tiền không hề có trong câu -> Từ chối ngay
        continue;
      }

      // 2. Chốt chặn Deterministic Parsing: Dart tự tính toán số tiền
      final amount = LocalRuleBasedTransactionParser.parseAmountFromText(amountToken);
      if (amount <= 0 || amount.isNaN || amount.isInfinite) {
        // Số tiền không hợp lệ hoặc <= 0 -> Bỏ qua
        continue;
      }

      // 3. Chuẩn hóa Loại giao dịch (Type)
      final type = (item.type.toLowerCase().trim() == 'inflow') ? 'inflow' : 'outflow';
      final isIncome = (type == 'inflow');

      // 4. Khớp Danh mục (Category Alignment)
      final category = _resolveCategory(
        categoryHint: item.categoryHint,
        note: item.note,
        availableCategories: availableCategories,
        isIncome: isIncome,
      );

      // 5. Chuẩn hóa Ghi chú (Note Formatting)
      var note = item.note.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (note.isNotEmpty) {
        note = note[0].toUpperCase() + note.substring(1);
      }

      // 6. Xử lý thời gian cho riêng giao dịch nếu ghi chú có chỉ định
      String itemDateIso = defaultDateIso;
      final noteLower = note.toLowerCase();
      final noteNorm = LocalRuleBasedTransactionParser.removeAccents(noteLower);
      if (noteLower.contains('hôm qua') || noteNorm.contains('hom qua')) {
        final d = DateTime.tryParse(currentTime) ?? DateTime.now();
        itemDateIso = d.subtract(const Duration(days: 1)).toUtc().toIso8601String();
      } else if (noteLower.contains('hôm kia') || noteNorm.contains('hom kia')) {
        final d = DateTime.tryParse(currentTime) ?? DateTime.now();
        itemDateIso = d.subtract(const Duration(days: 2)).toUtc().toIso8601String();
      }

      validatedList.add({
        'amount': amount,
        'type': type,
        'categoryName': category,
        'note': note,
        'date': itemDateIso,
      });
    }

    return validatedList;
  }

  /// Kiểm tra xem mốc tiền có thực sự nằm trong câu gốc hay không (Grounding Check)
  static bool _isGroundedInText(String amountToken, String rawText) {
    final lowerToken = amountToken.toLowerCase().trim();
    final lowerRaw = rawText.toLowerCase();

    // 1. So khớp trực tiếp chuỗi token
    if (lowerRaw.contains(lowerToken)) return true;

    // 2. So khớp không dấu
    final normToken = LocalRuleBasedTransactionParser.removeAccents(lowerToken);
    final normRaw = LocalRuleBasedTransactionParser.removeAccents(lowerRaw);
    if (normRaw.contains(normToken)) return true;

    // 3. So khớp phần số thuần (chữ số)
    final digitsInToken = lowerToken.replaceAll(RegExp(r'\D'), '');
    final digitsInRaw = lowerRaw.replaceAll(RegExp(r'\D'), '');
    if (digitsInToken.isNotEmpty && digitsInRaw.contains(digitsInToken)) {
      return true;
    }

    return false;
  }

  /// Đối chiếu danh mục an toàn, tránh nhận diện nhầm
  static String? _resolveCategory({
    required String? categoryHint,
    required String note,
    required List<String> availableCategories,
    required bool isIncome,
  }) {
    if (availableCategories.isEmpty) return null;

    // 1. Thử khớp trực tiếp với categoryHint (nếu AI cung cấp)
    if (categoryHint != null && categoryHint.trim().isNotEmpty) {
      final hint = categoryHint.trim();
      final hintLower = hint.toLowerCase();
      final hintNorm = LocalRuleBasedTransactionParser.removeAccents(hintLower);

      for (final cat in availableCategories) {
        final catLower = cat.toLowerCase();
        final catNorm = LocalRuleBasedTransactionParser.removeAccents(catLower);
        if (catLower == hintLower || catNorm == hintNorm) {
          return cat;
        }
      }

      // Thử dùng bộ quy tắc của Parser để tìm theo Hint
      final matchedFromHint = LocalRuleBasedTransactionParser.matchCategoryDirectly(
        text: hint,
        availableCategories: availableCategories,
        isIncome: isIncome,
      );
      if (matchedFromHint != null) return matchedFromHint;
    }

    // 2. Thử khớp theo nội dung Note
    if (note.trim().isNotEmpty) {
      final matchedFromNote = LocalRuleBasedTransactionParser.matchCategoryDirectly(
        text: note,
        availableCategories: availableCategories,
        isIncome: isIncome,
      );
      if (matchedFromNote != null) return matchedFromNote;
    }

    // 3. Nếu không tìm thấy mối tương quan rõ ràng -> Để trống (null)
    return null;
  }
}

