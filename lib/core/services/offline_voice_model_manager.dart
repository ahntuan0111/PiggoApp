import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appintern/core/errors/error_handler.dart';

/// Quản lý gói nhận diện tiếng Việt ngoại tuyến (Offline Voice Model)
/// Kích thước ~40MB, lưu trong bộ nhớ máy để nhận dạng giọng nói khi mất mạng hoàn toàn.
class OfflineVoiceModelManager extends GetxService {
  static const String _prefModelDownloadedKey = 'offline_voice_model_downloaded';
  static const String _prefModelVersionKey = 'offline_voice_model_version';
  static const String currentModelVersion = '1.0.0';

  // URL dự phòng tải gói model tiếng Việt gọn nhẹ (Vosk VN small / Whisper ggml tiny)
  // Được cấu hình mặc định để tải ngầm khi có Internet
  static const String modelDownloadUrl =
      'https://alphacephei.com/vosk/models/vosk-model-small-vn-0.4.zip';

  final RxBool isDownloaded = false.obs;
  final RxBool isDownloading = false.obs;
  final RxDouble downloadProgress = 0.0.obs;
  final RxString statusMessage = ''.obs;

  final Dio _dio = Dio();

  @override
  void onInit() {
    super.onInit();
    checkModelStatus();
  }

  /// Lấy thư mục lưu trữ gói model tiếng Việt
  Future<Directory> getModelDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/models/stt/vi');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// Kiểm tra xem gói model tiếng Việt đã có trong bộ nhớ máy chưa
  Future<bool> isModelDownloaded() async {
    final result = await ErrorHandler.execute(() async {
      final prefs = await SharedPreferences.getInstance();
      final hasPref = prefs.getBool(_prefModelDownloadedKey) ?? false;
      final modelDir = await getModelDirectory();

      final exists = await modelDir.exists();
      if (exists) {
        final files = modelDir.listSync();
        return files.isNotEmpty || hasPref;
      }
      return false;
    }, tag: "CHECK_OFFLINE_VOICE_MODEL");

    return result.fold(
      (failure) {
        isDownloaded.value = false;
        return false;
      },
      (hasFiles) {
        isDownloaded.value = hasFiles;
        return hasFiles;
      },
    );
  }

  /// Kiểm tra trạng thái và cập nhật Observable
  Future<void> checkModelStatus() async {
    await isModelDownloaded();
  }

  /// Tự động tải ngầm gói tiếng Việt (~43MB) khi có kết nối mạng
  Future<bool> downloadOfflineModelIfNeeded({
    void Function(double progress)? onProgress,
  }) async {
    if (await isModelDownloaded()) {
      statusMessage.value = 'Gói tiếng Việt ngoại tuyến đã sẵn sàng';
      return true;
    }

    if (isDownloading.value) return false;

    isDownloading.value = true;
    downloadProgress.value = 0.0;
    statusMessage.value = 'Đang tải gói nhận diện tiếng Việt ngoại tuyến (~40MB)...';

    final result = await ErrorHandler.execute(() async {
      final modelDir = await getModelDirectory();
      final zipFilePath = '${modelDir.path}/model_vn.zip';

      await _dio.download(
        modelDownloadUrl,
        zipFilePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final prog = received / total;
            downloadProgress.value = prog;
            if (onProgress != null) {
              onProgress(prog);
            }
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      // Đánh dấu đã tải thành công
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefModelDownloadedKey, true);
      await prefs.setString(_prefModelVersionKey, currentModelVersion);
      return true;
    }, tag: "DOWNLOAD_OFFLINE_VOICE_MODEL");

    return result.fold(
      (failure) {
        isDownloading.value = false;
        statusMessage.value = 'Tải gói ngoại tuyến tạm dừng: ${failure.message}';
        return false;
      },
      (success) {
        isDownloaded.value = true;
        isDownloading.value = false;
        downloadProgress.value = 1.0;
        statusMessage.value = 'Đã tải xong gói nhận diện tiếng Việt ngoại tuyến!';
        return true;
      },
    );
  }

  /// Xóa model nếu cần giải phóng bộ nhớ
  Future<void> clearDownloadedModel() async {
    final result = await ErrorHandler.execute(() async {
      final modelDir = await getModelDirectory();
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefModelDownloadedKey);
      await prefs.remove(_prefModelVersionKey);
      return true;
    }, tag: "CLEAR_OFFLINE_VOICE_MODEL");

    result.fold(
      (failure) => debugPrint('[OfflineVoiceModelManager] Clear error: ${failure.message}'),
      (_) => isDownloaded.value = false,
    );
  }
}
