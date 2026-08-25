import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:appwrite/appwrite.dart';

import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
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
import 'package:appintern/data/repositories/rollover_repository.dart' as appintern3;
import 'package:appintern/core/routes/app_routes.dart';

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

  late Worker _networkWorker;

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
    _networkWorker = ever(_networkService.isOffline, (isOffline) {
      if (!isOffline) {
        // Thay vì gọi trực tiếp ở đây, network_service sẽ gọi handleNetworkRestore()
        // Nhưng nếu muốn gọi ở đây luôn thì cũng được.
      }
    });
  }

  Future<void> handleNetworkRestore() async {
    if (_budgetService.isMonthTransitioning.value) return;

    try {
      _budgetService.isMonthTransitioning.value = true;
      
      // 1. Đồng bộ dữ liệu lên cloud với Timeout
      await startForegroundSync().timeout(const Duration(seconds: 15));

      // 2. Check Rollover
      final rolloverRepo = Get.find<appintern3.RolloverRepository>();
      final rolloverResult = await rolloverRepo.checkRolloverState().timeout(const Duration(seconds: 10));

      if (rolloverResult.state == appintern3.RolloverState.newAccount) {
         final storage = Get.find<StorageService>();
         final userId = storage.read(AppKeys.userId);
         if (userId != null) {
            await rolloverRepo.executeHardReset(userId).timeout(const Duration(seconds: 15));
         }
      } else if (rolloverResult.state == appintern3.RolloverState.multiMonthGap) {
         Get.offAllNamed(Routes.MULTI_MONTH_GAP, arguments: {
           'state': rolloverResult.state,
           'lastActiveMonthYear': rolloverResult.lastActiveMonthYear,
         });
      } else if (rolloverResult.state == appintern3.RolloverState.normalRollover) {
         // Cần popup cho người dùng chọn, nên điều hướng sang Month End Report (rồi sau đó là Rollover Decision)
         Get.offAllNamed(Routes.MONTH_END_REPORT, arguments: {
            'state': rolloverResult.state,
            'lastActiveMonthYear': rolloverResult.lastActiveMonthYear,
         });
      }

      warmUpCache();
    } catch (e) {
      AppLogger.error("SYNC", "Network Restore Timeout hoặc Lỗi: $e");
      Get.snackbar(
        "Đồng bộ lỗi",
        "Đồng bộ chuyển tháng thất bại do kết nối kém. Đang sử dụng dữ liệu Offline.",
      );
    } finally {
      _budgetService.isMonthTransitioning.value = false;
    }
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

    // Reset các task đang kẹt ở PROCESSING (do bị crash hoặc tắt app đột ngột) về PENDING
    await _localDb.resetProcessingTasks();
    Get.find<OfflineSyncService>().triggerQueueUpdate();

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
            await _localDb.updateTaskStatus(id, 'PROCESSING');
            // Notify UI
            Get.find<OfflineSyncService>().triggerQueueUpdate();

            final parsedDataString = await _processTask(type, payload);
            await _localDb.updateOfflineTaskParsedData(
              id,
              parsedDataString,
              'NEEDS_CONFIRMATION',
            );
            Get.find<OfflineSyncService>().triggerQueueUpdate();
            successCount++;
            // Rate Limit delay (3 seconds) between AI calls
            await Future.delayed(const Duration(seconds: 3));
          } else {
            // Manual tasks do not need AI parsing or confirmation
            await _processManualTask(type, payload);
            await _localDb.deleteTask(id);
            Get.find<OfflineSyncService>().triggerQueueUpdate();
            await Future.delayed(const Duration(milliseconds: 200));
          }
        } on AppwriteException catch (e) {
          AppLogger.error(
            "SYNC_ENGINE",
            "Task $id AppwriteException: ${e.code} - ${e.message}",
          );
          if (e.code == 400 ||
              e.code == 403 ||
              e.code == 404 ||
              e.code == 409) {
            await _localDb.updateTaskStatus(id, 'FAILED_PERMANENT');
            await _localDb.rollbackOptimisticTransaction(type, payload);
            Get.find<OfflineSyncService>().triggerQueueUpdate();
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
              e.statusCode == 404 ||
              e.statusCode == 409) {
            await _localDb.updateTaskStatus(id, 'FAILED_PERMANENT');
            await _localDb.rollbackOptimisticTransaction(type, payload);
            Get.find<OfflineSyncService>().triggerQueueUpdate();
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
            Get.find<OfflineSyncService>().triggerQueueUpdate();
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
            Get.find<OfflineSyncService>().triggerQueueUpdate();
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

  late final Map<String, Future<void> Function(Map<String, dynamic>)>
  _taskHandlers = {
    'CREATE_MANUAL_TX': _handleCreateManualTx,
    'UPDATE_MANUAL_TX': _handleUpdateManualTx,
    'DELETE_MANUAL_TX': _handleDeleteManualTx,
    'CREATE_WALLET_ADJUSTMENT': _handleCreateWalletAdjustment,
    'UPDATE_WALLET_ADJUSTMENT': _handleUpdateWalletAdjustment,
    'CREATE_CATEGORY_TYPE': _handleCreateCategoryType,
    'CREATE_CATEGORY': _handleCreateCategory,
    'UPDATE_CATEGORY_TYPE': _handleUpdateCategoryType,
    'DELETE_CATEGORY_TYPE': _handleDeleteCategoryType,
    'UPDATE_CATEGORY': _handleUpdateCategory,
    'DELETE_CATEGORY': _handleDeleteCategory,
    'UPDATE_BUDGET': _handleUpdateBudget,
    'TRANSFER_BUDGET': _handleUpdateBudget,
    'DELETE_ORPHANED_FILE': _handleDeleteOrphanedFile,
    'CREATE_GOAL': _handleCreateGoal,
    'UPDATE_GOAL': _handleUpdateGoal,
    'DELETE_GOAL': _handleDeleteGoal,
  };

  Future<void> _processManualTask(String type, String payload) async {
    final Map<String, dynamic> data = jsonDecode(payload);
    final handler = _taskHandlers[type];
    if (handler != null) {
      await handler(data);
    } else {
      AppLogger.error("SYNC_ENGINE", "Unknown manual task type: $type");
    }
  }

  Future<void> _handleCreateManualTx(Map<String, dynamic> data) async {
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

    final newTx = await _transactionRepo.createTransaction(
      transaction: tx,
      transactionDetail: txDetail,
      currentCategory: currentCategory,
    );
    if (data['tempId'] != null) {
      // NOTE: For manual transactions, local cache is managed differently (they are kept until next sync refresh),
      // but replacing tempId in queued tasks (like UPDATE/DELETE) is critical.
      await _localDb.replaceTempIdInTasks(data['tempId'], newTx.id);
    }
  }

  Future<void> _handleUpdateManualTx(Map<String, dynamic> data) async {
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
  }

  Future<void> _handleDeleteManualTx(Map<String, dynamic> data) async {
    final txId = data['transactionId'];
    final amount = data['amount'];
    final txType = data['type'];
    final txDateStr = data['transactionDate'];
    final txDate = txDateStr != null
        ? DateTime.parse(txDateStr)
        : DateTime.now();

    final tx = TransactionModel(
      id: txId,
      categoryId: data['category']?['id'] ?? '',
      amount: amount.toDouble(),
      type: txType,
      transactionDate: txDate,
      status: 'COMPLETED',
    );

    final categoryData = data['category'];
    CategoryModel? category;
    if (categoryData != null) {
      category = CategoryModel.fromMap(categoryData);
    }

    await _transactionRepo.deleteTransaction(
      transaction: tx,
      currentCategory: category,
    );
  }

  Future<void> _handleCreateWalletAdjustment(Map<String, dynamic> data) async {
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

    final newTx = await _transactionRepo.createWalletAdjustmentTransaction(
      transaction: tx,
      transactionDetail: txDetail,
    );
    if (data['tempId'] != null) {
      await _localDb.replaceTempIdInTasks(data['tempId'], newTx.id);
    }
  }

  Future<void> _handleUpdateWalletAdjustment(Map<String, dynamic> data) async {
    final txData = data['transaction'];
    final tx = TransactionModel.fromMap(txData);

    final detailData = data['detail'];
    final txDetail = TransactionDetailModel.fromMap(detailData);

    final oldTxData = data['oldTransaction'];
    final oldTransaction = TransactionModel.fromMap(oldTxData);

    await _transactionRepo.updateWalletAdjustmentTransaction(
      oldTransaction: oldTransaction,
      newTransaction: tx,
      newTransactionDetail: txDetail,
    );
  }

  Future<void> _handleCreateCategoryType(Map<String, dynamic> data) async {
    final storage = Get.find<StorageService>();
    final userId = storage.read<String>(AppKeys.userId) ?? '';
    final newType = await _categoryRepo.createCategoryType(
      userId,
      data['name'] as String,
      data['priority'] as int? ?? 0,
    );
    if (data['tempId'] != null) {
      await _localDb.deleteCategoryType(data['tempId']);
      await _localDb.replaceTempIdInTasks(data['tempId'], newType.id);
    }
  }

  Future<void> _handleCreateCategory(Map<String, dynamic> data) async {
    final newCat = await _categoryRepo.createCategory(
      data['typeId'],
      data['name'],
      data['iconName'],
      data['color'],
      isActive: data['isActive'] ?? true,
    );
    if (data['tempId'] != null) {
      await _localDb.deleteCategory(data['tempId']);
      await _localDb.replaceTempIdInTasks(data['tempId'], newCat.id);
    }
  }

  Future<void> _handleUpdateCategoryType(Map<String, dynamic> data) async {
    await _categoryRepo.updateCategoryType(data['id'], data['name']);
  }

  Future<void> _handleDeleteCategoryType(Map<String, dynamic> data) async {
    await _categoryRepo.deleteCategoryType(data['id']);
  }

  Future<void> _handleUpdateCategory(Map<String, dynamic> data) async {
    await _categoryRepo.updateCategory(
      data['id'],
      data['name'],
      data['iconName'],
      data['color'],
    );
  }

  Future<void> _handleDeleteCategory(Map<String, dynamic> data) async {
    await _categoryRepo.deleteCategory(data['id']);
  }

  Future<void> _handleUpdateBudget(Map<String, dynamic> data) async {
    final monthYear = data['monthYear'];
    final allocations = List<Map<String, dynamic>>.from(data['allocations']);
    final transferLogs = data['transferLogs'] != null
        ? List<Map<String, dynamic>>.from(data['transferLogs'])
        : null;
    await _categoryRepo.transferBudget(
      monthYear,
      allocations,
      transferLogs: transferLogs,
    );

    // Đảm bảo monthly_budgets được cập nhật trên Appwrite (Bypass Cloud Function)
    for (var alloc in allocations) {
      final categoryId = alloc['categoryId'];
      final newBudget = (alloc['amount'] as num).toDouble();
      final mb = _budgetService.getBudgetForCategory(categoryId);
      if (mb != null) {
        await _categoryRepo.updateMonthlyBudget(mb.id, newBudget);
      } else {
        final cat = _budgetService.categories.firstWhereOrNull((c) => c.categoryModel.id == categoryId);
        await _categoryRepo.createMonthlyBudget(
          categoryId: categoryId,
          monthYear: monthYear,
          budgetedAmount: newBudget,
          spentAmount: cat?.spent ?? 0.0,
        );
      }
    }
  }

  Future<void> _handleDeleteOrphanedFile(Map<String, dynamic> data) async {
    final fileId = data['fileId'];
    if (fileId != null) {
      await _storageRepo.deleteFile(fileId);
    }
  }

  Future<void> _handleCreateGoal(Map<String, dynamic> data) async {
    final goalData = data['goal'];
    if (goalData['id'] != null &&
        goalData['id'].toString().startsWith('offline_')) {
      goalData.remove('id');
    }
    final goal = GoalModel.fromMap(goalData);
    final newGoal = await Get.find<GoalRepository>().createGoal(goal);
    if (data['tempId'] != null) {
      await _localDb.deleteLocalGoal(data['tempId']);
      await _localDb.replaceTempIdInTasks(data['tempId'], newGoal.id);
    }
  }

  Future<void> _handleUpdateGoal(Map<String, dynamic> data) async {
    final goalData = data['goal'];
    final goal = GoalModel.fromMap(goalData);
    await Get.find<GoalRepository>().updateGoal(goal);

    final categoryUpdate = data['categoryUpdate'];
    if (categoryUpdate != null) {
      await _categoryRepo.updateCategory(
        categoryUpdate['id'],
        categoryUpdate['name'],
        categoryUpdate['iconName'],
        categoryUpdate['color'],
      );
    }
  }

  Future<void> _handleDeleteGoal(Map<String, dynamic> data) async {
    final goalId = data['goalId'];
    final categoryId = data['categoryId'];
    await Get.find<GoalRepository>().deleteGoal(goalId);
    await _categoryRepo.deleteCategory(categoryId);
  }

  @override
  void onClose() {
    _networkWorker.dispose();
    super.onClose();
  }
}
