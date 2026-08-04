import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/errors/exceptions.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/data/data_sources/remote/appwrite_ai_service_impl.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:appintern/core/utils/logger.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';

class SyncEngineService extends GetxService {
  final LocalDatabaseService _localDb = Get.find<LocalDatabaseService>();
  final NetworkService _networkService = Get.find<NetworkService>();
  final AppwriteAIServiceImpl _aiService = Get.find<AppwriteAIServiceImpl>();
  final TransactionRepository _transactionRepo =
      Get.find<TransactionRepository>();
  final CategoryRepository _categoryRepo = Get.find<CategoryRepository>();
  final BudgetService _budgetService = Get.find<BudgetService>();
  final StorageRepository _storageRepo = Get.find<StorageRepository>();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isSyncing = false;

  @override
  void onInit() {
    super.onInit();
    _initNotifications();

    // Khởi động chạy nền và cache khi mở app
    if (!_networkService.isOffline.value) {
      warmUpCache();
      startForegroundSync();
    }

    // Lắng nghe trạng thái mạng để tự động chạy
    ever(_networkService.isOffline, (isOffline) {
      if (!isOffline) {
        warmUpCache();
        startForegroundSync();
      }
    });
  }

  /// Tải ngầm 15 giao dịch mới nhất của tháng hiện tại để sẵn sàng khi Offline
  Future<void> warmUpCache() async {
    if (_networkService.isOffline.value) return;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final txsResult = await ErrorHandler.execute(() async {
      return await _transactionRepo.getTransactionsByFilters(
        start: start,
        end: end,
        limit: 15,
        ascending: false,
      );
    }, tag: "SYNC_ENGINE_FETCH");

    txsResult.fold(
      (fail) => AppLogger.error(
        'SyncEngineService',
        'Lỗi tải ngầm dữ liệu: ${fail.message}',
      ),
      (txs) async {
        if (txs.isNotEmpty) {
          final models = txs
              .map((e) => e['transaction'] as TransactionModel)
              .toList();
          final saveResult = await ErrorHandler.execute(() async {
            await _transactionRepo.saveTransactionsToCache(models);
          }, tag: "SYNC_ENGINE_CACHE");

          saveResult.fold(
            (fail) => AppLogger.error(
              'SyncEngineService',
              'Lỗi lưu cache ngầm: ${fail.message}',
            ),
            (_) => AppLogger.info(
              'SyncEngineService',
              'Đã tải ngầm ${models.length} giao dịch vào Cache.',
            ),
          );
        }
      },
    );
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
          if (type == 'TEXT' || type == 'IMAGE' || type == 'VOICE') {
            final parsedDataString = await _processTask(type, payload);
            await _localDb.updateOfflineTaskParsedData(
              id,
              parsedDataString,
              'NEEDS_CONFIRMATION',
            );
            successCount++;
            // Rate Limit delay (3 seconds) between AI calls
            await Future.delayed(const Duration(seconds: 3));
          } else {
            // Manual tasks do not need AI parsing or confirmation
            await _processManualTask(type, payload);
            await _localDb.deleteTask(id);
            await Future.delayed(const Duration(milliseconds: 200));
          }
        } on AppwriteException catch (e) {
          AppLogger.error(
            "SYNC_ENGINE",
            "Task $id AppwriteException: \${e.code} - \${e.message}",
          );
          if (e.code == 400 || e.code == 403 || e.code == 409) {
            await _localDb.updateTaskStatus(id, 'FAILED_PERMANENT');
            await _localDb.rollbackOptimisticTransaction(type, payload);
            _showNotification(
              "Giao dịch bị từ chối",
              "Một giao dịch vừa bị hệ thống từ chối. Số dư đã được khôi phục.",
            );
          } else {
            rethrow;
          }
        } on ServerException catch (e) {
          AppLogger.error(
            "SYNC_ENGINE",
            "Task $id ServerException: ${e.statusCode} - ${e.message}",
          );
          if (e.statusCode == 400 ||
              e.statusCode == 403 ||
              e.statusCode == 409) {
            await _localDb.updateTaskStatus(id, 'FAILED_PERMANENT');
            await _localDb.rollbackOptimisticTransaction(type, payload);
            _showNotification(
              "Giao dịch bị từ chối",
              "Một giao dịch vừa bị hệ thống từ chối. Số dư đã được khôi phục.",
            );
          } else {
            rethrow;
          }
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
    final currentTime = DateTime.now().toUtc().toIso8601String();

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

  Future<void> _processManualTask(String type, String payload) async {
    final Map<String, dynamic> data = jsonDecode(payload);

    if (type == 'CREATE_MANUAL_TX') {
      final txData = data['transaction'];
      if (txData['id'] != null &&
          txData['id'].toString().startsWith('offline_')) {
        txData.remove('id');
      }
      final tx = TransactionModel.fromMap(txData);

      final detailData = data['detail'];
      if (detailData['id'] != null &&
          detailData['id'].toString().startsWith('offline_')) {
        detailData.remove('id');
      }
      final txDetail = TransactionDetailModel.fromMap(detailData);

      final categoryData = data['category'];
      CategoryModel? currentCategory;
      if (categoryData != null) {
        currentCategory = CategoryModel.fromMap(categoryData);
      }

      await _transactionRepo.createTransaction(
        transaction: tx,
        transactionDetail: txDetail,
        currentCategory: currentCategory,
      );
    } else if (type == 'UPDATE_MANUAL_TX') {
      final txData = data['transaction'];
      final tx = TransactionModel.fromMap(txData);

      final detailData = data['detail'];
      final txDetail = TransactionDetailModel.fromMap(detailData);

      final oldCategoryData = data['oldCategory'];
      CategoryModel? oldCategory;
      if (oldCategoryData != null) {
        oldCategory = CategoryModel.fromMap(oldCategoryData);
      }

      final newCategoryData = data['newCategory'];
      CategoryModel? newCategory;
      if (newCategoryData != null) {
        newCategory = CategoryModel.fromMap(newCategoryData);
      }

      final oldTxData = data['oldTransaction'];
      final oldTransaction = TransactionModel.fromMap(oldTxData);

      await _transactionRepo.updateTransaction(
        oldTransaction: oldTransaction,
        newTransaction: tx,
        newTransactionDetail: txDetail,
        oldCategory: oldCategory,
        newCategory: newCategory,
      );
    } else if (type == 'CREATE_CATEGORY_TYPE') {
      final storage = Get.find<StorageService>();
      final userId = storage.read<String>(AppKeys.userId) ?? '';
      await _categoryRepo.createCategoryType(
        userId,
        data['name'] as String,
        data['priority'] as int? ?? 0,
      );
      if (data['tempId'] != null) {
        await _localDb.deleteCategoryType(data['tempId']);
      }
    } else if (type == 'CREATE_CATEGORY') {
      final newCat = await _categoryRepo.createCategory(
        data['typeId'],
        data['name'],
        data['iconName'],
        data['color'],
      );
      if (data['tempId'] != null) {
        await _localDb.deleteCategory(data['tempId']);
        await _localDb.replaceTempIdInTasks(data['tempId'], newCat.id);
      }
    } else if (type == 'UPDATE_CATEGORY_TYPE') {
      await _categoryRepo.updateCategoryType(data['id'], data['name']);
    } else if (type == 'DELETE_CATEGORY_TYPE') {
      await _categoryRepo.deleteCategoryType(data['id']);
    } else if (type == 'UPDATE_CATEGORY') {
      await _categoryRepo.updateCategory(
        data['id'],
        data['name'],
        data['iconName'],
        data['color'],
      );
    } else if (type == 'DELETE_CATEGORY') {
      await _categoryRepo.deleteCategory(data['id']);
    } else if (type == 'UPDATE_BUDGET' || type == 'TRANSFER_BUDGET') {
      final monthYear = data['monthYear'];
      final allocations = List<Map<String, dynamic>>.from(data['allocations']);
      final transferLogs = data['transferLogs'] != null 
          ? List<Map<String, dynamic>>.from(data['transferLogs'])
          : null;
      await _categoryRepo.transferBudget(monthYear, allocations, transferLogs: transferLogs);
    } else if (type == 'DELETE_ORPHANED_FILE') {
      final fileId = data['fileId'];
      if (fileId != null) {
        await _storageRepo.deleteFile(fileId);
      }
    }
  }
}
