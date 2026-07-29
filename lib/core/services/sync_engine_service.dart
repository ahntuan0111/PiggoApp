import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/data/data_sources/remote/appwrite_ai_service_impl.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:appintern/core/utils/logger.dart';

class SyncEngineService extends GetxService {
  final LocalDatabaseService _localDb = Get.find<LocalDatabaseService>();
  final NetworkService _networkService = Get.find<NetworkService>();
  final AppwriteAIServiceImpl _aiService = Get.find<AppwriteAIServiceImpl>();
  final TransactionRepository _transactionRepo =
      Get.find<TransactionRepository>();
  final BudgetService _budgetService = Get.find<BudgetService>();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isSyncing = false;

  @override
  void onInit() {
    super.onInit();
    _initNotifications();
    // Lắng nghe trạng thái mạng để tự động chạy
    ever(_networkService.isOffline, (isOffline) {
      if (!isOffline) {
        startForegroundSync();
      }
    });
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          macOS: initializationSettingsDarwin,
        );
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {},
    );
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'offline_sync_channel',
          'Đồng bộ dữ liệu Offline',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> startForegroundSync() async {
    if (_isSyncing) return;
    if (_networkService.isOffline.value) return;

    // Database Lock: Chống chạy trùng giữa UI Isolate và Background Isolate
    final lockAcquired = await _localDb.acquireSyncLock();
    if (!lockAcquired) return;

    _isSyncing = true;
    int successCount = 0;

    try {
      while (true) {
        if (_networkService.isOffline.value) break;

        final tasks = await _localDb.getPendingTasks();
        if (tasks.isEmpty) break;

        final task = tasks.first;
        final String id = task['id'];
        final String type = task['task_type'];
        final String payload = task['payload'];
        int retryCount = task['retry_count'] as int;

        try {
          final parsedDataString = await _processTask(type, payload);
          await _localDb.updateOfflineTaskParsedData(
            id,
            parsedDataString,
            'NEEDS_CONFIRMATION',
          );
          successCount++;
          // Rate Limit delay (3 seconds) between AI calls
          await Future.delayed(const Duration(seconds: 3));
        } catch (e) {
          AppLogger.error("SYNC_ENGINE", "Task $id failed: $e");
          retryCount++;
          if (retryCount >= 5) {
            await _localDb.updateTaskStatus(id, 'FAILED'); // Quá giới hạn retry
          } else {
            // Exponential backoff
            final delaySeconds = 15 * retryCount;
            final nextRetry = DateTime.now()
                .add(Duration(seconds: delaySeconds))
                .toIso8601String();
            await _localDb.updateTaskStatus(
              id,
              'PENDING',
              retryCount: retryCount,
              nextRetryTime: nextRetry,
            );
            break; // Thoát khỏi vòng lặp, để lần sync tiếp theo xử lý
          }
        }
      }

      if (successCount > 0) {
        _showNotification(
          "Giao dịch chờ xác nhận",
          "Có $successCount giao dịch từ chế độ ngoại tuyến cần bạn xác nhận.",
        );
        // Refresh Budget & Home (Chỉ khi ở UI Isolate)
        if (Get.isRegistered<BudgetService>()) {
          _budgetService.refreshData();
        }
      }
    } finally {
      _isSyncing = false;
      await _localDb.releaseSyncLock();
      // Update ui queue count (Chỉ update nếu đang ở UI Isolate)
      if (Get.isRegistered<OfflineSyncService>()) {
        Get.find<OfflineSyncService>().refreshQueueCount();
      }
    }
  }

  Future<String> _processTask(String type, String payload) async {
    final availableCategories = _budgetService.activeCategories
        .map((c) => c.name)
        .toList();
    final currentTime = DateTime.now().toIso8601String();

    List<Map<String, dynamic>> parsedTxs = [];

    if (type == 'TEXT') {
      parsedTxs = await _aiService.parseTransactionText(
        text: payload,
        availableCategories: availableCategories,
        currentTime: currentTime,
      );
    } else if (type == 'IMAGE') {
      parsedTxs = await _aiService.parseReceiptImage(
        imageFile: File(payload),
        availableCategories: availableCategories,
        currentTime: currentTime,
      );
    } else if (type == 'VOICE') {
      final text = await _aiService.convertSpeechToText(payload);
      parsedTxs = await _aiService.parseTransactionText(
        text: text,
        availableCategories: availableCategories,
        currentTime: currentTime,
      );
    }

    if (parsedTxs.isNotEmpty) {
      return jsonEncode(parsedTxs);
    }

    throw Exception('Không có dữ liệu hợp lệ trả về từ AI');
  }
}
