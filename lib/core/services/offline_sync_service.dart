import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';
import 'package:appintern/ui/widgets/dialogs/offline_queue_full_dialog.dart';

class OfflineSyncService extends GetxService {
  final LocalDatabaseService _localDb = Get.find<LocalDatabaseService>();
  static const int MAX_AI_TASKS = 3;
  static const int MAX_MANUAL_TASKS = 7;

  final aiQueueCount = 0.obs;
  final manualQueueCount = 0.obs;
  final queueUpdateTrigger = 0.obs;

  void triggerQueueUpdate() {
    queueUpdateTrigger.value++;
    refreshQueueCount();
  }

  @override
  void onInit() {
    super.onInit();
    refreshQueueCount();
  }

  Future<void> refreshQueueCount() async {
    final tasks = await _localDb.getPendingTasks();
    aiQueueCount.value = tasks
        .where(
          (t) =>
              t['task_type'] == 'TEXT' ||
              t['task_type'] == 'IMAGE' ||
              t['task_type'] == 'VOICE',
        )
        .length;
    manualQueueCount.value = tasks
        .where(
          (t) =>
              t['task_type'] != 'TEXT' &&
              t['task_type'] != 'IMAGE' &&
              t['task_type'] != 'VOICE',
        )
        .length;
  }

  Future<void> queueTask(String type, String payload) async {
    final id = ID.unique(); // CR-06: Collision-proof ID thay cho timestamp
    await _localDb.addOfflineTask(id: id, taskType: type, payload: payload);
    await refreshQueueCount();

    // Đăng ký Background Sync (Sẽ chạy ngay khi có mạng)
    Workmanager().registerOneOffTask(
      "global_offline_sync",
      "offlineSyncTask", // Tên task
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected, // Bắt buộc phải có mạng mới chạy
      ),
    );
  }

  /// Xử lý hành động ngoại tuyến (Lazy Input)
  /// Trả về true nếu đang offline (đã đưa vào hàng chờ hoặc báo lỗi quá tải)
  /// Trả về false nếu đang online (để tiếp tục xử lý online)
  Future<bool> handleOfflineAction(
    String type,
    String payload, {
    required String successMessage,
    bool isFile = false,
    bool showSnackbar = true,
  }) async {
    final networkService = Get.find<NetworkService>();
    if (!networkService.isOffline.value) {
      return false; // Online
    }

    // Giới hạn 5 task AI tổng cộng
    if (aiQueueCount.value >= MAX_AI_TASKS) {
      OfflineQueueFullDialog.show(
        currentCount: aiQueueCount.value,
        maxCount: MAX_AI_TASKS,
        isAiTask: true,
      );
      return true; // Đã xử lý (Offline nhưng đầy)
    }

    String finalPayload = payload;
    if (isFile) {
      final docDir = await getApplicationDocumentsDirectory();
      final extension = payload.split('.').last;
      final fileName =
          '${type.toLowerCase()}_offline_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final savedFile = await File(payload).copy('${docDir.path}/$fileName');
      finalPayload = savedFile.path;
    }

    await queueTask(type, finalPayload);
    if (showSnackbar) {
      Get.snackbar(
        'Ngoại tuyến',
        successMessage,
        // fallback if color is missing, though we should avoid hardcoding
        backgroundColor: Get.theme.colorScheme.secondary,
        colorText: Get.theme.colorScheme.onSecondary,
      );
    }
    return true; // Đã xử lý (đưa vào queue thành công)
  }

  bool checkAndShowManualQueueFull() {
    if (manualQueueCount.value >= MAX_MANUAL_TASKS) {
      OfflineQueueFullDialog.show(
        currentCount: manualQueueCount.value,
        maxCount: MAX_MANUAL_TASKS,
        isAiTask: false,
      );
      return true;
    }
    return false;
  }

  /// Đưa tác vụ thủ công (tạo giao dịch, tạo danh mục) vào hàng đợi.
  Future<void> queueManualTask(String type, String payload) async {
    if (manualQueueCount.value >= MAX_MANUAL_TASKS) {
      OfflineQueueFullDialog.show(
        currentCount: manualQueueCount.value,
        maxCount: MAX_MANUAL_TASKS,
        isAiTask: false,
      );
      return;
    }

    await queueTask(type, payload);
  }
}
