import 'package:appintern/data/models/hybrid_transaction_models.dart';

/// Hợp đồng trừu tượng (Interface) cho các mô hình AI On-Device chạy cục bộ
/// Cho phép hoán đổi linh hoạt giữa FunctionGemma 270M, Qwen 0.5B hoặc Mock Engine
abstract class IOnDeviceAiEngine {
  /// Tên định danh của mô hình (vd: 'FunctionGemma-270M', 'Qwen-0.5B-GGUF')
  String get modelName;

  /// Trạng thái mô hình đã được nạp vào bộ nhớ RAM thiết bị hay chưa
  bool get isModelLoaded;

  /// Khởi tạo và nạp trọng số mô hình vào RAM (On-Demand)
  Future<bool> initialize();

  /// Bóc tách văn bản đầu vào thành danh sách các item thô (JSON Schema)
  Future<List<RawAiTransactionItem>> parse(String input);

  /// Giải phóng mô hình khỏi RAM khi không còn nhu cầu sử dụng
  Future<void> unload();
}

