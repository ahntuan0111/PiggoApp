import 'package:collection/collection.dart';

/// Bộ bóc tách câu nói/văn bản tiếng Việt thành giao dịch tài chính
/// Hoạt động 100% Offline trên RAM thiết bị, không tốn Token, không cần mạng, độ trễ < 1ms.
/// Hỗ trợ tiếng Việt có dấu, không dấu, từ lóng, và nhiều giao dịch liên tiếp.
class LocalRuleBasedTransactionParser {
  static final List<String> _incomeKeywords = [
    'nhận',
    'nhan',
    'lương',
    'luong',
    'thưởng',
    'thuong',
    'bán',
    'ban',
    'đòi được',
    'doi duoc',
    'thu',
    'hoàn tiền',
    'hoan tien',
    'được cho',
    'duoc cho',
    'tiền về',
    'tien ve',
    'cộng',
    'cong',
    'lãi',
    'lai',
  ];

  /// Biểu thức chính quy bóc tách số tiền và đơn vị tiếng Việt lóng
  static final RegExp moneyRegex = RegExp(
    r'(\d+(?:[\.,]\d+)*)\s*(k|cành|canh|củ|cu|tr|triệu|trieu|nghìn|nghin|ngàn|ngan|lít|lit|xị|xi|đ|d|vnd|đồng|dong)?(?![a-zA-Z0-9_à-ỹÀ-ỸđĐ])',
    caseSensitive: false,
  );

  /// Tiện ích công khai bóc tách số tiền từ chuỗi số tiền thô (vd: "50k", "1.500.000đ", "200 cành")
  static double parseAmountFromText(String amountText) {
    final clean = amountText.trim();
    if (clean.isEmpty) return 0.0;
    final match = moneyRegex.firstMatch(clean);
    if (match == null) {
      final norm = clean.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(norm) ?? 0.0;
    }
    return _parseAmount(match.group(1), match.group(2));
  }

  /// Tiện ích công khai đối chiếu và khớp danh mục trực tiếp
  static String? matchCategoryDirectly({
    required String text,
    required List<String> availableCategories,
    required bool isIncome,
  }) {
    return _matchCategory(text.toLowerCase(), availableCategories, isIncome);
  }

  /// Loại bỏ dấu tiếng Việt để so khớp không dấu (vd: "đổ xăng" -> "do xang")
  static String removeAccents(String text) {
    var str = text;
    str = str.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    str = str.replaceAll(RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'), 'A');
    str = str.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    str = str.replaceAll(RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'), 'E');
    str = str.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    str = str.replaceAll(RegExp(r'[ÌÍỊỈĨ]'), 'I');
    str = str.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    str = str.replaceAll(RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'), 'O');
    str = str.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
    str = str.replaceAll(RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'), 'U');
    str = str.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    str = str.replaceAll(RegExp(r'[ỲÝỴỶỸ]'), 'Y');
    str = str.replaceAll(RegExp(r'[đ]'), 'd');
    str = str.replaceAll(RegExp(r'[Đ]'), 'D');
    return str;
  }

  /// Kiểm tra từ khóa có xuất hiện trong chuỗi không, tránh match phụ âm/nguyên âm bên trong từ khác
  /// (vd: 'an' không được match trong 'canh', 'xang', 'quan')
  static bool _containsKeyword(String text, String keyword) {
    if (keyword.length <= 3) {
      final pattern = RegExp(
        '(?:^|[^a-zA-Z0-9_à-ỹÀ-ỸđĐ])${RegExp.escape(keyword)}(?:[^a-zA-Z0-9_à-ỹÀ-ỸđĐ]|\$)',
        caseSensitive: false,
      );
      return pattern.hasMatch(text);
    }
    return text.contains(keyword);
  }

  /// Xác định loại giao dịch: inflow (thu nhập) hay outflow (chi tiêu)
  static String _determineType(String lowerText, String normText) {
    final isIncome = _incomeKeywords.any(
      (kw) => _containsKeyword(lowerText, kw) || _containsKeyword(normText, kw),
    );
    return isIncome ? 'inflow' : 'outflow';
  }

  /// Phân tách các mệnh đề an toàn (Safe Clause Splitting):
  /// - Phân biệt dấu phẩy thập phân (1,5 triệu) với dấu phẩy ngăn cách mệnh đề.
  /// - Bắt buộc các liên từ (và, va, với, voi) phải có ranh giới từ để tránh nuốt từ (vd: "mua vali 50").
  /// - Xử lý dấu phân cách +, ;
  static List<String> _splitClausesSafely(String text) {
    final cuts = <List<int>>[];

    // 1. Chỉ nhận diện từ nối khi chúng đứng độc lập
    final conjunctionRegex = RegExp(
      r'(?:^|\s+)(?:và|va|với|voi)(?:\s+|$)',
      caseSensitive: false,
    );

    for (final match in conjunctionRegex.allMatches(text)) {
      cuts.add([match.start, match.end]);
    }

    bool isDigitAt(int index) {
      if (index < 0 || index >= text.length) return false;
      final code = text.codeUnitAt(index);
      return code >= 48 && code <= 57;
    }

    // 2. Dấu phân cách dấu câu (+, ;, ,)
    for (var i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == ';' || char == '+') {
        cuts.add([i, i + 1]);
        continue;
      }

      if (char == ',') {
        // Dấu phẩy nằm giữa 2 chữ số (vd: 1,5) là dấu thập phân, KHÔNG cắt
        final isDecimalComma = isDigitAt(i - 1) && isDigitAt(i + 1);
        if (!isDecimalComma) {
          cuts.add([i, i + 1]);
        }
      }
    }

    if (cuts.isEmpty) {
      return [text.trim()];
    }

    cuts.sort((a, b) => a[0].compareTo(b[0]));

    final clauses = <String>[];
    var cursor = 0;

    for (final cut in cuts) {
      if (cut[0] < cursor) {
        if (cut[1] > cursor) cursor = cut[1];
        continue;
      }

      final clause = text.substring(cursor, cut[0]).trim();
      if (clause.isNotEmpty) {
        clauses.add(clause);
      }
      cursor = cut[1];
    }

    final tail = text.substring(cursor).trim();
    if (tail.isNotEmpty) {
      clauses.add(tail);
    }

    return clauses.isEmpty ? [text.trim()] : clauses;
  }

  /// Kiểm tra xem match có phải là mốc tiền rõ ràng (Explicit Money) hay không.
  /// Mốc tiền rõ ràng: có đơn vị tiền tệ rõ ràng (k, cành, củ, triệu, ...) hoặc định dạng hàng nghìn (50.000) hoặc >= 1000.
  static bool _isExplicitMoney(String? rawNum, String? unit) {
    if (unit != null && unit.trim().isNotEmpty) return true;
    if (rawNum == null) return false;

    if (rawNum.contains('.') || rawNum.contains(',')) {
      final parts = rawNum.split(RegExp(r'[\.,]'));
      if (parts.length > 1 && parts.last.length == 3) {
        return true;
      }
    }

    final normNum = rawNum.replaceAll(',', '.');
    final val = double.tryParse(normNum) ?? 0.0;
    if (val >= 1000) return true;

    return false;
  }

  /// Loại bỏ các tiền tố thời gian để phục vụ nhận diện cấu trúc vị trí số tiền
  static String _stripTimePrefixes(String text) {
    var s = text.trim();
    final timeRegex = RegExp(
      r'^(?:hôm nay|hom nay|sáng nay|sang nay|trưa nay|trua nay|chiều nay|chieu nay|tối nay|toi nay|hôm qua|hom qua|hôm kia|hom kia|sáng|sang|trưa|trua|chiều|chieu|tối|toi)(?=$|\s|[,.;:!?])\s*',
      caseSensitive: false,
    );
    while (true) {
      final matched = timeRegex.firstMatch(s);
      if (matched != null && matched.start == 0) {
        s = s.substring(matched.end).trim();
      } else {
        break;
      }
    }
    return s;
  }

  /// Tìm match tương ứng trong chuỗi con subText
  static RegExpMatch? _findBestMatchInSubText(
    String subText,
    List<RegExpMatch> subMatches,
    RegExpMatch originalMatch,
  ) {
    if (subMatches.isEmpty) return null;
    final targetText = originalMatch.group(0)?.trim();
    final exact = subMatches.firstWhereOrNull((m) => m.group(0)?.trim() == targetText);
    if (exact != null) return exact;
    return subMatches.first;
  }

  /// Phân đoạn một mệnh đề khi chứa nhiều mốc tiền (Pattern A hoặc Pattern B)
  static List<_TransactionSegment> _segmentMultiMatchClause(
    String clause,
    List<RegExpMatch> candidates,
    RegExp moneyRegex,
  ) {
    final firstMatch = candidates.first;
    final lastMatch = candidates.last;

    final textBeforeFirst = clause.substring(0, firstMatch.start).trim();
    final textAfterLast = clause.substring(lastMatch.end).trim();

    // Loại bỏ tiền tố thời gian để kiểm tra xem trước số đầu tiên có nội dung mô tả không
    final textBeforeWithoutTime = _stripTimePrefixes(textBeforeFirst);

    // Nếu trước số đầu tiên có nội dung mô tả (hoặc sau số cuối không có mô tả):
    // Pattern A: [Desc 1] [Amt 1] [Desc 2] [Amt 2] ...
    final isDescBeforeAmount = textBeforeWithoutTime.isNotEmpty || textAfterLast.isEmpty;

    final segments = <_TransactionSegment>[];

    if (isDescBeforeAmount) {
      // Pattern A: Mô tả đứng trước số tiền
      for (int i = 0; i < candidates.length; i++) {
        final start = (i == 0) ? 0 : candidates[i - 1].end;
        final end = (i == candidates.length - 1) ? clause.length : candidates[i].end;
        final subText = clause.substring(start, end).trim();
        if (subText.isNotEmpty) {
          final subMatches = moneyRegex.allMatches(subText).toList();
          final bestSubMatch = _findBestMatchInSubText(subText, subMatches, candidates[i]);
          if (bestSubMatch != null) {
            segments.add(_TransactionSegment(text: subText, amountMatch: bestSubMatch));
          }
        }
      }
    } else {
      // Pattern B: Số tiền đứng trước mô tả
      for (int i = 0; i < candidates.length; i++) {
        final start = (i == 0) ? 0 : candidates[i].start;
        final end = (i == candidates.length - 1) ? clause.length : candidates[i + 1].start;
        final subText = clause.substring(start, end).trim();
        if (subText.isNotEmpty) {
          final subMatches = moneyRegex.allMatches(subText).toList();
          final bestSubMatch = _findBestMatchInSubText(subText, subMatches, candidates[i]);
          if (bestSubMatch != null) {
            segments.add(_TransactionSegment(text: subText, amountMatch: bestSubMatch));
          }
        }
      }
    }

    return segments;
  }

  /// Phân đoạn một mệnh đề độc lập
  static List<_TransactionSegment> _segmentClause(String clause, RegExp moneyRegex) {
    final allMatches = moneyRegex.allMatches(clause).toList();
    final matches = allMatches.where((m) {
      if (m.start > 0 && clause[m.start - 1] == '-') return false;
      return true;
    }).toList();
    if (matches.isEmpty) return [];

    final explicitMatches = <RegExpMatch>[];
    final bareMatches = <RegExpMatch>[];

    for (final match in matches) {
      final rawNum = match.group(1);
      final unit = match.group(2);
      if (_isExplicitMoney(rawNum, unit)) {
        explicitMatches.add(match);
      } else {
        bareMatches.add(match);
      }
    }

    // Nếu có mốc tiền rõ ràng, chỉ dùng mốc tiền rõ ràng;
    // Các số trần khác (như "2" trong "mua 2 áo 200k") được xem là số lượng hàng hóa và giữ lại trong mô tả
    final candidateMatches = explicitMatches.isNotEmpty ? explicitMatches : bareMatches;

    if (candidateMatches.length == 1) {
      return [
        _TransactionSegment(
          text: clause,
          amountMatch: candidateMatches.first,
        ),
      ];
    }

    return _segmentMultiMatchClause(clause, candidateMatches, moneyRegex);
  }

  /// Phân tích văn bản tiếng Việt thành danh sách giao dịch Map
  static List<Map<String, dynamic>> parse({
    required String text,
    required List<String> availableCategories,
    required String currentTime,
  }) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return [];

    final lowerText = cleanText.toLowerCase();
    final normText = removeAccents(lowerText);

    // Thời gian mặc định
    DateTime baseDate = DateTime.tryParse(currentTime) ?? DateTime.now();
    if (lowerText.contains('hôm qua') || normText.contains('hom qua') || lowerText.contains('qua')) {
      baseDate = baseDate.subtract(const Duration(days: 1));
    } else if (lowerText.contains('hôm kia') || normText.contains('hom kia')) {
      baseDate = baseDate.subtract(const Duration(days: 2));
    }
    final defaultDateIso = baseDate.toUtc().toIso8601String();

    final allMatches = moneyRegex.allMatches(cleanText).where((m) {
      if (m.start > 0 && cleanText[m.start - 1] == '-') return false;
      return true;
    }).toList();
    if (allMatches.isEmpty) {
      final type = _determineType(lowerText, normText);
      final isIncome = (type == 'inflow');
      final matchedCategory = _matchCategory(lowerText, availableCategories, isIncome);
      return [
        {
          'amount': 0.0,
          'type': type,
          'categoryName': matchedCategory,
          'note': cleanText,
          'date': defaultDateIso,
        }
      ];
    }

    // Bước 1: Tách các mệnh đề an toàn
    final clauses = _splitClausesSafely(cleanText);

    // Bước 2: Phân đoạn từng mệnh đề theo mốc tiền đã chọn
    final segments = <_TransactionSegment>[];
    for (final clause in clauses) {
      segments.addAll(_segmentClause(clause, moneyRegex));
    }

    // Nếu không tạo được phân đoạn nào (biên an toàn), fallback dùng toàn bộ match
    if (segments.isEmpty) {
      for (final match in allMatches) {
        segments.add(_TransactionSegment(text: cleanText, amountMatch: match));
      }
    }

    final List<Map<String, dynamic>> results = [];

    // Bước 3: Xử lý độc lập từng phân đoạn (số tiền, ghi chú, danh mục, loại thu/chi)
    for (final segment in segments) {
      final segText = segment.text;
      final match = segment.amountMatch;

      final amount = _parseAmount(match.group(1), match.group(2));
      final note = _cleanNote(segText, match);

      // Phân loại độc lập cho từng phân đoạn (tránh câu gồm cả thu và chi bị gán cùng loại)
      final segLower = segText.toLowerCase();
      final segNorm = removeAccents(segLower);
      final segType = _determineType(segLower, segNorm);
      final isIncome = (segType == 'inflow');
      final category = _matchCategory(segLower, availableCategories, isIncome);

      // Trích xuất thời gian riêng cho phân đoạn nếu có
      String segDateIso = defaultDateIso;
      if (segLower.contains('hôm qua') || segNorm.contains('hom qua') || segLower.contains('qua')) {
        DateTime d = DateTime.tryParse(currentTime) ?? DateTime.now();
        segDateIso = d.subtract(const Duration(days: 1)).toUtc().toIso8601String();
      } else if (segLower.contains('hôm kia') || segNorm.contains('hom kia')) {
        DateTime d = DateTime.tryParse(currentTime) ?? DateTime.now();
        segDateIso = d.subtract(const Duration(days: 2)).toUtc().toIso8601String();
      }

      results.add({
        'amount': amount,
        'type': segType,
        'categoryName': category,
        'note': note, // Không fallback sang toàn bộ phân đoạn nếu rỗng
        'date': segDateIso,
      });
    }

    return results;
  }

  /// Tính toán số tiền dựa trên số gốc và đơn vị từ lóng
  static double _parseAmount(String? rawNum, String? unit) {
    if (rawNum == null) return 0.0;
    var s = rawNum.trim();
    final u = unit?.toLowerCase().trim() ?? '';

    final isMultiplierUnit = (u == 'k' ||
        u == 'cành' ||
        u == 'canh' ||
        u == 'củ' ||
        u == 'cu' ||
        u == 'tr' ||
        u == 'triệu' ||
        u == 'trieu' ||
        u == 'lít' ||
        u == 'lit' ||
        u == 'xị' ||
        u == 'xi');

    if (isMultiplierUnit) {
      // Với đơn vị có hệ số nhân (k, triệu, củ...): dấu chấm hoặc phẩy là dấu thập phân (vd: 1.5 triệu, 12,5k)
      s = s.replaceAll(',', '.');
    } else {
      // Với số tiền đầy đủ (không có đơn vị hoặc đơn vị là đ, vnd, đồng):
      // Dấu chấm hoặc phẩy là dấu phân cách hàng nghìn (vd: 20.000đ, 1.500.000đ, 20.000)
      if (s.contains('.')) {
        final dotParts = s.split('.');
        if (dotParts.length > 2 || (dotParts.length == 2 && dotParts[1].length == 3)) {
          s = s.replaceAll('.', '');
        } else {
          s = s.replaceAll(',', '.');
        }
      } else if (s.contains(',')) {
        final commaParts = s.split(',');
        if (commaParts.length > 2 || (commaParts.length == 2 && commaParts[1].length == 3)) {
          s = s.replaceAll(',', '');
        } else {
          s = s.replaceAll(',', '.');
        }
      }
    }

    final val = double.tryParse(s) ?? 0.0;

    if (u == 'k' || u == 'cành' || u == 'canh' || u == 'nghìn' || u == 'nghin' || u == 'ngàn' || u == 'ngan') {
      return val * 1000;
    } else if (u == 'củ' || u == 'cu' || u == 'tr' || u == 'triệu' || u == 'trieu') {
      return val * 1000000;
    } else if (u == 'xị' || u == 'xi' || u == 'lít' || u == 'lit') {
      return val * 100000;
    } else {
      // Nếu số nhỏ hơn 1000 và không có đơn vị, người dùng thường nói tắt "45", "50", "55", "500" nghĩa là 45k, 50k, 55k, 500k
      if (val > 0 && val < 1000 && u.isEmpty) {
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

    final normText = removeAccents(lowerText).toLowerCase();

    if (isIncome) {
      final incomeCatKeywords = ['lương', 'luong', 'thu nhập', 'thu nhap', 'thưởng', 'thuong'];
      return availableCategories.firstWhereOrNull((c) {
        final cNorm = removeAccents(c.toLowerCase());
        return incomeCatKeywords.any((kw) => cNorm.contains(kw));
      });
    }

    // BƯỚC 1: So khớp trực tiếp tên danh mục của người dùng (ưu tiên tên dài trước, khớp từ nguyên vẹn)
    final sortedCategories = List<String>.from(availableCategories)
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final cat in sortedCategories) {
      final catNorm = removeAccents(cat.toLowerCase()).trim();
      if (catNorm.isEmpty) continue;
      if (_containsKeyword(lowerText, cat.toLowerCase()) || _containsKeyword(normText, catNorm)) {
        return cat;
      }
    }

    // BƯỚC 2: Từ điển ngữ nghĩa từ lóng & mặt hàng tiếng Việt -> Danh mục tương ứng
    final categoryRules = <_CategoryKeywordRule>[
      _CategoryKeywordRule(
        categoryKeywords: ['ăn', 'an', 'uống', 'uong', 'ẩm thực', 'am thuc', 'food'],
        inputKeywords: [
          'ăn', 'an', 'phở', 'pho', 'bún', 'bun', 'bún bò', 'bun bo', 'cơm', 'com',
          'trà', 'tra', 'cafe', 'cà phê', 'ca phe', 'bánh', 'banh', 'uống', 'uong',
          'ăn sáng', 'an sang', 'ăn trưa', 'an trua', 'ăn tối', 'an toi',
          'bữa sáng', 'bua sang', 'bữa trưa', 'bua trua', 'bữa tối', 'bua toi',
          'bánh mì', 'banh mi', 'lẩu', 'lau', 'nướng', 'nuong', 'chè', 'che', 'nước', 'nuoc',
          'trà sữa', 'tra sua', 'highlands', 'starbucks', 'kfc', 'lotteria',
          'pizza', 'mì', 'mi', 'hủ tiếu', 'hu tieu', 'xôi', 'xoi', 'nhà hàng', 'nha hang',
          'quán ăn', 'quan an', 'quán cơm', 'quan com', 'quán phở', 'quan pho', 'quán nước', 'quan nuoc',
          'gà rán', 'ga ran', 'nem', 'thịt bò', 'thit bo', 'cháo', 'chao',
        ],
      ),
      _CategoryKeywordRule(
        categoryKeywords: ['xăng', 'xang', 'xe', 'di chuyển', 'di chuyen', 'đi lại', 'di lai', 'transport'],
        inputKeywords: [
          'xăng', 'xang', 'đổ xăng', 'do xang', 'grab', 'xe', 'gửi xe', 'gui xe',
          'rửa xe', 'rua xe', 'be', 'gojek', 'taxi', 'vé xe', 've xe', 'bảo dưỡng', 'bao duong',
          'nhớt', 'nhot', 'vé tàu', 've tau', 'vé máy bay', 've may bay', 'bus',
          'xe buýt', 'xe buyt', 'xe máy', 'xe may', 'thay nhớt', 'thay nhot', 'xăm', 'xam',
          'lốp', 'lop', 'vá xe', 'va xe',
        ],
      ),
      _CategoryKeywordRule(
        categoryKeywords: ['mua', 'sắm', 'sam', 'shopping', 'chợ', 'cho', 'siêu thị', 'sieu thi'],
        inputKeywords: [
          'mua', 'sắm', 'sam', 'quần', 'quan', 'áo', 'ao', 'shopee', 'lazada',
          'siêu thị', 'sieu thi', 'tiki', 'giày', 'giay', 'dép', 'dep', 'mỹ phẩm', 'my pham',
          'sách', 'sach', 'mua đồ', 'mua do', 'sắm đồ', 'sam do', 'đồ dùng', 'do dung',
          'bách hóa', 'bach hoa', 'circle k', 'winmart', 'vinmart',
          'chợ', 'cho', 'tiktok shop',
        ],
      ),
      _CategoryKeywordRule(
        categoryKeywords: ['nhà', 'nha', 'thuê', 'thue', 'trọ', 'tro', 'phòng', 'phong', 'rent'],
        inputKeywords: [
          'tiền nhà', 'tien nha', 'thuê nhà', 'thue nha', 'tiền trọ', 'tien tro',
          'tiền phòng', 'tien phong', 'trọ', 'tro', 'phòng trọ', 'phong tro',
        ],
      ),
      _CategoryKeywordRule(
        categoryKeywords: ['hóa đơn', 'hoa don', 'điện', 'dien', 'nước', 'nuoc', 'dịch vụ', 'dich vu', 'bill'],
        inputKeywords: [
          'điện', 'dien', 'nước', 'nuoc', 'internet', 'wifi', 'nạp tiền điện thoại', 'nap tien dien thoai',
          'nạp card', 'nap card', '4g', 'cước', 'cuoc', 'tiền mạng', 'tien mang', 'học phí', 'hoc phi',
          'hóa đơn', 'hoa don',
        ],
      ),
      _CategoryKeywordRule(
        categoryKeywords: ['giải trí', 'giai tri', 'vui chơi', 'vui choi', 'entertainment'],
        inputKeywords: [
          'phim', 'rạp', 'rap', 'cgv', 'lotte', 'netflix', 'game', 'du lịch', 'du lich',
          'hát', 'hat', 'karaoke', 'bida', 'bi-a', 'bar', 'pub', 'vé', 've',
        ],
      ),
      _CategoryKeywordRule(
        categoryKeywords: ['sức khỏe', 'suc khoe', 'y tế', 'y te', 'thuốc', 'thuoc', 'gym'],
        inputKeywords: [
          'thuốc', 'thuoc', 'khám', 'kham', 'bác sĩ', 'bac si', 'bệnh viện', 'benh vien',
          'nha khoa', 'gym', 'yoga', 'thuốc tây', 'thuoc tay',
        ],
      ),
    ];

    for (final rule in categoryRules) {
      final hasMatchingKeyword = rule.inputKeywords.any((kw) {
        final kwNorm = removeAccents(kw.toLowerCase());
        return _containsKeyword(lowerText, kw) || _containsKeyword(normText, kwNorm);
      });

      if (hasMatchingKeyword) {
        final matchedCat = sortedCategories.firstWhereOrNull((c) {
          final cNorm = removeAccents(c.toLowerCase());
          return rule.categoryKeywords.any((targetKw) {
            final tKwNorm = removeAccents(targetKw.toLowerCase());
            return c.toLowerCase().contains(targetKw) || cNorm.contains(tKwNorm);
          });
        });

        if (matchedCat != null) return matchedCat;
      }
    }

    return null;
  }

  /// Làm sạch ghi chú sau khi bóc tách mốc tiền đã chọn
  static String _cleanNote(String originalText, RegExpMatch match) {
    // 1. Thay thế đúng vị trí mốc tiền đã chọn bằng khoảng trắng
    var note = originalText.replaceRange(match.start, match.end, ' ');

    // 2. Gộp khoảng trắng liên tiếp
    note = note.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 3. Xóa các cụm từ chỉ thời gian rõ ràng ở đầu (có ranh giới từ để tránh xóa nhầm vd "tối ưu")
    final timePrefix = RegExp(
      r'^(?:hôm nay|hom nay|sáng nay|sang nay|'
      r'trưa nay|trua nay|chiều nay|chieu nay|'
      r'tối nay|toi nay|hôm qua|hom qua|'
      r'hôm kia|hom kia)'
      r'(?=$|\s|[,.;:!?])\s*',
      caseSensitive: false,
    );
    note = note.replaceFirst(timePrefix, '').trim();

    // Xóa từ thời gian đơn lẻ (sáng, trưa, chiều) KHI đi kèm từ hành động/tiêu dùng phía sau
    // Tuyệt đối không xóa "tối/toi" vì "toi" là đại từ "Tôi" (vd: "toi mua do an")
    final singleTimePrefix = RegExp(
      r'^(?:sáng|sang|trưa|trua|chiều|chieu)\s+(?=(?:ăn|an|uống|uong|mua|đi|di|đổ|do|trả|tra|gửi|gui|chi|thuê|thue)\b)',
      caseSensitive: false,
    );
    note = note.replaceFirst(singleTimePrefix, '').trim();

    // 4. Xóa từ đệm chi phí rõ ràng ở đầu (chỉ xóa "hết", không xóa "mất/mat" để tránh nuốt "mắt kính/mat kinh")
    final fillerPrefix = RegExp(
      r'^(?:hết|het)\s+',
      caseSensitive: false,
    );
    note = note.replaceFirst(fillerPrefix, '').trim();

    // 5. Chuẩn hóa khoảng trắng lần cuối
    note = note.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (note.isEmpty) return '';

    // Viết hoa chữ cái đầu tiên
    return note[0].toUpperCase() + note.substring(1);
  }
}

/// Đại diện một phân đoạn giao dịch gắn liền với mốc tiền đã chọn
class _TransactionSegment {
  final String text;
  final RegExpMatch amountMatch;

  const _TransactionSegment({
    required this.text,
    required this.amountMatch,
  });
}

class _CategoryKeywordRule {
  final List<String> categoryKeywords;
  final List<String> inputKeywords;

  const _CategoryKeywordRule({
    required this.categoryKeywords,
    required this.inputKeywords,
  });
}
