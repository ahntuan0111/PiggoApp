import 'package:collection/collection.dart';

/// Bộ bóc tách câu nói/văn bản tiếng Việt thành giao dịch tài chính
/// Hoạt động 100% Offline trên RAM thiết bị, không tốn Token, không cần mạng, độ trễ < 1ms.
class LocalRuleBasedTransactionParser {
  /// Phân tích văn bản tiếng Việt thành danh sách giao dịch Map
  static List<Map<String, dynamic>> parse({
    required String text,
    required List<String> availableCategories,
    required String currentTime,
  }) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return [];

    final lowerText = cleanText.toLowerCase();

    // 1. Phân loại inflow (thu nhập) hay outflow (chi tiêu)
    final incomeKeywords = [
      'nhận',
      'lương',
      'thưởng',
      'bán',
      'đòi được',
      'thu',
      'hoàn tiền',
      'được cho',
      'tiền về',
      'cộng',
      'lãi',
    ];
    final isIncome = incomeKeywords.any((kw) => lowerText.contains(kw));
    final type = isIncome ? 'inflow' : 'outflow';

    // 2. Trích xuất thời gian (Hỗ trợ hôm qua, hôm kia, hôm nay)
    DateTime baseDate = DateTime.tryParse(currentTime) ?? DateTime.now();
    if (lowerText.contains('hôm qua') || lowerText.contains('qua')) {
      baseDate = baseDate.subtract(const Duration(days: 1));
    } else if (lowerText.contains('hôm kia')) {
      baseDate = baseDate.subtract(const Duration(days: 2));
    }
    final dateIso = baseDate.toUtc().toIso8601String();

    // 3. Khớp danh mục dựa trên từ điển từ khóa tiếng Việt
    String? matchedCategory = _matchCategory(lowerText, availableCategories, isIncome);

    // 4. Regex bóc tách số tiền và đơn vị tiếng Việt lóng
    // Match: 45k, 45 cành, 2 củ, 500 nghìn, 1.5 triệu, 20.000đ, 50000
    final moneyRegex = RegExp(
      r'(\d+(?:[\.,]\d+)?)\s*(k|cành|củ|tr|triệu|nghìn|ngàn|lít|xị|đ|vnd|đồng)?\b',
      caseSensitive: false,
    );

    final matches = moneyRegex.allMatches(cleanText).toList();
    if (matches.isEmpty) {
      // Nếu không tìm thấy số tiền cụ thể, trả về 1 item mặc định 0đ
      return [
        {
          'amount': 0.0,
          'type': type,
          'categoryName': matchedCategory,
          'note': cleanText,
          'date': dateIso,
        }
      ];
    }

    // Nếu văn bản có nhiều số tiền nối nhau bằng từ như "và", "với", ","
    // thì bóc tách thành các giao dịch riêng biệt
    final List<Map<String, dynamic>> results = [];

    // Tách các phân đoạn nếu có nhiều mệnh đề
    final clauses = cleanText.split(RegExp(r'\s*(?:và|với|,|\+)\s*', caseSensitive: false));

    if (clauses.length > 1) {
      for (final clause in clauses) {
        final clauseLower = clause.toLowerCase();
        final clauseMatches = moneyRegex.allMatches(clause).toList();
        if (clauseMatches.isNotEmpty) {
          final firstMatch = clauseMatches.first;
          final amount = _parseAmount(firstMatch.group(1), firstMatch.group(2));
          final clauseCat = _matchCategory(clauseLower, availableCategories, isIncome) ?? matchedCategory;
          final note = _cleanNote(clause, firstMatch);

          results.add({
            'amount': amount,
            'type': type,
            'categoryName': clauseCat,
            'note': note.isNotEmpty ? note : cleanText,
            'date': dateIso,
          });
        }
      }
    }

    // Nếu không tách được theo clauses hoặc chỉ có 1 mệnh đề
    if (results.isEmpty) {
      for (final match in matches) {
        final amount = _parseAmount(match.group(1), match.group(2));
        final note = _cleanNote(cleanText, match);

        results.add({
          'amount': amount,
          'type': type,
          'categoryName': matchedCategory,
          'note': note.isNotEmpty ? note : cleanText,
          'date': dateIso,
        });
      }
    }

    return results;
  }

  /// Tính toán số tiền dựa trên số gốc và đơn vị từ lóng
  static double _parseAmount(String? rawNum, String? unit) {
    if (rawNum == null) return 0.0;
    final normalizedNum = rawNum.replaceAll(',', '.');
    final val = double.tryParse(normalizedNum) ?? 0.0;

    final u = unit?.toLowerCase().trim() ?? '';
    if (u == 'k' || u == 'cành' || u == 'nghìn' || u == 'ngàn') {
      return val * 1000;
    } else if (u == 'củ' || u == 'tr' || u == 'triệu') {
      return val * 1000000;
    } else if (u == 'xị' || u == 'lít') {
      return val * 100000;
    } else {
      // Nếu số nhỏ hơn 1000 và không có đơn vị, người dùng thường nói tắt "45" nghĩa là 45k
      if (val > 0 && val < 500 && u.isEmpty) {
        return val * 1000;
      }
      return val;
    }
  }

  /// Khớp danh mục dựa trên danh sách danh mục hiện có của người dùng
  static String? _matchCategory(
    String lowerText,
    List<String> availableCategories,
    bool isIncome,
  ) {
    if (availableCategories.isEmpty) return null;

    if (isIncome) {
      return availableCategories.firstWhereOrNull(
        (c) =>
            c.toLowerCase().contains('lương') ||
            c.toLowerCase().contains('thu nhập') ||
            c.toLowerCase().contains('thưởng'),
      );
    }

    // Từ điển từ khóa chi tiêu tiếng Việt
    final categoryRules = <String, List<String>>{
      'ăn': [
        'ăn',
        'phở',
        'bún',
        'cơm',
        'trà',
        'cafe',
        'cà phê',
        'bánh',
        'uống',
        'sáng',
        'trưa',
        'tối',
        'bánh mì',
        'lẩu',
        'nướng',
        'chè',
        'nước',
        'trà sữa',
        'highlands',
        'starbucks',
        'kfc',
        'lotteria',
      ],
      'xe': [
        'xăng',
        'grab',
        'xe',
        'gửi xe',
        'rửa xe',
        'be',
        'taxi',
        'vé xe',
        'bảo dưỡng',
        'nhớt',
        'vé tàu',
        'vé máy bay',
      ],
      'mua': [
        'mua',
        'quần',
        'áo',
        'shopee',
        'lazada',
        'siêu thị',
        'tiki',
        'giày',
        'dép',
        'mỹ phẩm',
        'sách',
        'đồ',
      ],
      'hóa đơn': [
        'điện',
        'nước',
        'internet',
        'wifi',
        'tiền phòng',
        'tiền nhà',
        'trọ',
        'học phí',
        'nạp tiền điện thoại',
      ],
      'giải trí': [
        'phim',
        'rạp',
        'cgv',
        'netflix',
        'game',
        'du lịch',
        'hát',
        'karaoke',
        'bida',
      ],
      'sức khỏe': [
        'thuốc',
        'khám',
        'bác sĩ',
        'bệnh viện',
        'nha khoa',
        'gym',
        'yoga',
      ],
    };

    for (final entry in categoryRules.entries) {
      final ruleKey = entry.key;
      final keywords = entry.value;

      if (keywords.any((kw) => lowerText.contains(kw))) {
        // Tìm danh mục có chứa ruleKey hoặc từ khóa
        final found = availableCategories.firstWhereOrNull(
          (c) => c.toLowerCase().contains(ruleKey),
        );
        if (found != null) return found;
      }
    }

    // Tìm trực tiếp nếu tên danh mục xuất hiện trong text
    for (final cat in availableCategories) {
      if (lowerText.contains(cat.toLowerCase())) {
        return cat;
      }
    }

    return null;
  }

  /// Làm sạch ghi chú sau khi bóc tách số tiền
  static String _cleanNote(String originalText, RegExpMatch match) {
    String note = originalText.replaceRange(match.start, match.end, '').trim();
    // Xóa bớt các từ đệm thời điểm ở đầu
    note = note.replaceAll(RegExp(r'^(?:hôm nay|sáng nay|trưa nay|chiều nay|tối nay|hôm qua|hôm kia|sáng|trưa|chiều|tối)\s*', caseSensitive: false), '');
    note = note.replaceAll(RegExp(r'^(?:tiền|hết|mất|trả|chi|mua)\s*', caseSensitive: false), '');
    note = note.trim();
    if (note.isEmpty) return originalText;
    // Viết hoa chữ cái đầu
    return note[0].toUpperCase() + note.substring(1);
  }
}
