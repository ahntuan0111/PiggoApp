abstract class IAIService {
  /// Phân tích đoạn văn bản tự nhiên thành dữ liệu giao dịch
  /// [text]: Đoạn văn bản người dùng nhập (vd: "sáng ăn phở 45k")
  /// [availableCategories]: Danh sách tên các danh mục hiện có
  /// [currentTime]: Thời gian hiện tại chuẩn ISO
  Future<List<Map<String, dynamic>>> parseTransactionText({
    required String text,
    required List<String> availableCategories,
    required String currentTime,
  });

  /// Chuyển đổi âm thanh thành văn bản thông qua Microservice STT (PhoWhisper)
  Future<String> convertSpeechToText(String audioPath);
}
