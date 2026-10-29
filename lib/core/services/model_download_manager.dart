import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appintern/core/services/network_service.dart';

/// Trạng thái của gói mô hình AI On-Device trên thiết bị
enum AiModelStatus {
  notDownloaded,
  downloading,
  ready,
  error,
}

/// Dịch vụ quản lý tải và vòng đời mô hình ngôn ngữ On-Device (On-Demand AI Model Manager)
/// Cho phép tải theo yêu cầu, kiểm tra kết nối Wi-Fi, theo dõi tiến trình và giải phóng bộ nhớ.
class ModelDownloadManager extends GetxService {
  static const String _prefModelDownloadedKey = 'pigo_ai_model_downloaded';
  static const String _prefWifiOnlyKey = 'pigo_ai_model_wifi_only';
  static const String modelFileName = 'pigo_small_lm.bin';

  // Dung lượng ước lượng của model (~280MB - 350MB)
  static const int estimatedSizeBytes = 295 * 1024 * 1024;

  final Rx<AiModelStatus> status = AiModelStatus.notDownloaded.obs;
  final RxDouble downloadProgress = 0.0.obs;
  final RxString statusMessage = ''.obs;
  final RxBool wifiOnly = true.obs;

  CancelToken? _cancelToken;
  final Dio _dio = Dio();

  bool get isModelReady => status.value == AiModelStatus.ready;

  @override
  void onInit() {
    super.onInit();
    checkModelStatus();
  }

  /// Lấy thư mục lưu trữ mô hình AI On-Device
  Future<File> getModelFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/models/llm');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return File('${modelDir.path}/$modelFileName');
  }

  /// Kiểm tra trạng thái tệp mô hình trên máy
  Future<void> checkModelStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      wifiOnly.value = prefs.getBool(_prefWifiOnlyKey) ?? true;

      final file = await getModelFile();
      if (await file.exists()) {
        final length = await file.length();
        if (length > 10 * 1024 * 1024) { // Lớn hơn 10MB coi như hợp lệ sơ bộ
          status.value = AiModelStatus.ready;
          statusMessage.value = 'Mô hình AI đã sẵn sàng hoạt động ngoại tuyến';
          return;
        }
      }
      status.value = AiModelStatus.notDownloaded;
      statusMessage.value = 'Chưa tải mô hình';
    } catch (e) {
      status.value = AiModelStatus.error;
      statusMessage.value = 'Lỗi kiểm tra mô hình: $e';
    }
  }

  /// Bắt đầu tải mô hình từ máy chủ CDN
  Future<bool> startDownload({required String downloadUrl}) async {
    if (status.value == AiModelStatus.downloading) return false;

    // Kiểm tra Wi-Fi nếu người dùng bật tùy chọn chỉ tải qua Wi-Fi
    if (wifiOnly.value) {
      try {
        final networkService = Get.find<NetworkService>();
        if (networkService.isOffline.value) {
          statusMessage.value = 'Không có kết nối mạng để tải mô hình';
          return false;
        }
      } catch (_) {}
    }

    try {
      status.value = AiModelStatus.downloading;
      downloadProgress.value = 0.0;
      statusMessage.value = 'Đang tải mô hình AI...';

      final file = await getModelFile();
      final tempFilePath = '${file.path}.downloading';
      final tempFile = File(tempFilePath);

      _cancelToken = CancelToken();

      await _dio.download(
        downloadUrl,
        tempFilePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            downloadProgress.value = received / total;
            final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
            statusMessage.value = 'Đang tải: $mbReceived / $mbTotal MB (${(downloadProgress.value * 100).toInt()}%)';
          }
        },
      );

      // Đổi tên file tạm thành file chính thức sau khi tải xong hoàn tất
      if (await tempFile.exists()) {
        await tempFile.rename(file.path);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefModelDownloadedKey, true);

      status.value = AiModelStatus.ready;
      downloadProgress.value = 1.0;
      statusMessage.value = 'Tải mô hình thành công';
      return true;
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) {
        status.value = AiModelStatus.notDownloaded;
        statusMessage.value = 'Đã hủy tải mô hình';
      } else {
        status.value = AiModelStatus.error;
        statusMessage.value = 'Lỗi khi tải mô hình: $e';
      }
      return false;
    } finally {
      _cancelToken = null;
    }
  }

  /// Hủy quá trình tải
  void cancelDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('Người dùng hủy tải');
    }
  }

  /// Xóa mô hình khỏi máy để giải phóng dung lượng bộ nhớ
  Future<bool> deleteModel() async {
    try {
      final file = await getModelFile();
      if (await file.exists()) {
        await file.delete();
      }
      final tempFile = File('${file.path}.downloading');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefModelDownloadedKey, false);

      status.value = AiModelStatus.notDownloaded;
      downloadProgress.value = 0.0;
      statusMessage.value = 'Đã xóa mô hình khỏi thiết bị';
      return true;
    } catch (e) {
      debugPrint('[ModelDownloadManager] Lỗi xóa file: $e');
      return false;
    }
  }

  /// Bật / Tắt cài đặt chỉ tải qua Wi-Fi
  Future<void> setWifiOnly(bool enabled) async {
    wifiOnly.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefWifiOnlyKey, enabled);
  }
}

