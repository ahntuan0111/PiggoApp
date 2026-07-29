import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';

class OfflineSyncService extends GetxService {
  final LocalDatabaseService _localDb = Get.find<LocalDatabaseService>();
  
  final aiQueueCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    refreshQueueCount();
  }

  Future<void> refreshQueueCount() async {
    aiQueueCount.value = await _localDb.getPendingQueueCount();
  }

  Future<void> queueTask(String type, String payload) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _localDb.addOfflineTask(id: id, taskType: type, payload: payload);
    await refreshQueueCount();
    
    // Đăng ký Background Sync (Sẽ chạy ngay khi có mạng)
    Workmanager().registerOneOffTask(
      "offlineSyncTask_$id",
      "offlineSyncTask", // Tên task
      constraints: Constraints(
        networkType: NetworkType.connected, // Bắt buộc phải có mạng mới chạy
      ),
    );
  }

  /// Xử lý hành động ngoại tuyến (Lazy Input)
  /// Trả về true nếu đang offline (đã đưa vào hàng chờ hoặc báo lỗi quá tải)
  /// Trả về false nếu đang online (để tiếp tục xử lý online)
  Future<bool> handleOfflineAction(String type, String payload, {required String successMessage, bool isFile = false}) async {
    final networkService = Get.find<NetworkService>();
    if (!networkService.isOffline.value) {
      return false; // Online
    }

    // Giới hạn 5 task AI tổng cộng (vì 1 task có thể sinh nhiều giao dịch)
    if (aiQueueCount.value >= 5) {
      Get.snackbar(
        "Hàng chờ đầy",
        "Hàng chờ xử lý AI đã đầy (5/5). Vui lòng kết nối mạng để đồng bộ.",
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return true; // Đã xử lý (Offline nhưng đầy)
    }

    String finalPayload = payload;
    if (isFile) {
      final docDir = await getApplicationDocumentsDirectory();
      final extension = payload.split('.').last;
      final fileName = '${type.toLowerCase()}_offline_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      final savedFile = await File(payload).copy('${docDir.path}/$fileName');
      finalPayload = savedFile.path;
    }

    await queueTask(type, finalPayload);
    Get.snackbar(
      'Ngoại tuyến',
      successMessage,
      // fallback if color is missing, though we should avoid hardcoding
      backgroundColor: Get.theme.colorScheme.secondary,
      colorText: Get.theme.colorScheme.onSecondary,
    );
    return true; // Đã xử lý (đưa vào queue thành công)
  }
}

