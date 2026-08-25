class Failure {
  final String message; // Technical message (chỉ dùng cho log)
  final String userMessage; // Thân thiện (hiển thị lên UI)
  final int? statusCode;
  final String? type;

  Failure({
    required this.message,
    this.statusCode,
    this.type,
    String? userMessage,
  }) : userMessage = userMessage ?? _toUserFriendly(message, statusCode);

  /// Chuyển đổi message kỹ thuật thành message thân thiện cho End User.
  /// Ưu tiên mapping theo statusCode, sau đó theo keyword trong message.
  static String _toUserFriendly(String technicalMsg, int? statusCode) {
    // 1. Mapping theo HTTP status code
    if (statusCode != null) {
      if (statusCode == 400) return 'Dữ liệu không hợp lệ, vui lòng kiểm tra lại.';
      if (statusCode == 401) return 'Phiên đăng nhập đã hết hạn.';
      if (statusCode == 403) return 'Bạn không có quyền thực hiện thao tác này.';
      if (statusCode == 404) return 'Không tìm thấy dữ liệu yêu cầu.';
      if (statusCode == 409) return 'Dữ liệu bị xung đột, vui lòng thử lại.';
      if (statusCode >= 500) return 'Máy chủ đang bận, vui lòng thử lại sau.';
    }

    // 2. Mapping theo keyword trong message
    final msg = technicalMsg.toLowerCase();
    if (msg.contains('socketexception') || msg.contains('network is unreachable')) {
      return 'Không có kết nối mạng, vui lòng kiểm tra lại.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Kết nối quá chậm, vui lòng thử lại.';
    }
    if (msg.contains('permission') || msg.contains('denied')) {
      return 'Bạn không có quyền thực hiện thao tác này.';
    }
    if (msg.contains('document') && msg.contains('not found')) {
      return 'Không tìm thấy dữ liệu yêu cầu.';
    }
    if (msg.contains('not a subtype') || msg.contains('null')) {
      return 'Đã xảy ra lỗi, vui lòng thử lại sau.';
    }

    // 3. Nếu message đã thân thiện sẵn (tiếng Việt, không chứa pattern kỹ thuật) → giữ nguyên
    if (_isUserFriendly(technicalMsg)) {
      return technicalMsg;
    }

    // 4. Fallback
    return 'Đã xảy ra lỗi, vui lòng thử lại sau.';
  }

  /// Kiểm tra xem message có "thân thiện" hay không.
  /// Nếu chứa các pattern kỹ thuật → không thân thiện.
  static bool _isUserFriendly(String message) {
    final technicalPatterns = [
      RegExp(r'[a-f0-9]{20,}'), // Database ID (hex string dài)
      RegExp(r'Exception|Error|Stack|Trace', caseSensitive: false),
      RegExp(r"type '.+' is not a subtype"),
      RegExp(r'Document with'),
      RegExp(r'Collection|Database|Index', caseSensitive: false),
      RegExp(r'[A-Z][a-z]+Exception'), // CamelCase exceptions
      RegExp(r'\.dart[:.]'), // Dart file references
    ];

    for (var pattern in technicalPatterns) {
      if (pattern.hasMatch(message)) return false;
    }
    return true;
  }
}
