import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:appwrite/appwrite.dart';

import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/ui/features/transaction/widgets/confirm_multiple_transactions_bottom_sheet.dart';
import 'package:appintern/ui/widgets/dialogs/loading_dialog_widget.dart';
import 'package:appintern/core/utils/logger.dart';
import 'package:appintern/core/errors/error_handler.dart';

import 'package:appintern/core/services/network_service.dart';

class OfflineQueueController extends BaseController {
  final LocalDatabaseService _localDb = Get.find<LocalDatabaseService>();
  final BudgetService budgetService = Get.find<BudgetService>();
  final OfflineSyncService offlineSyncService = Get.find<OfflineSyncService>();
  final NetworkService networkService = Get.find<NetworkService>();
  final StorageRepository storageRepository = Get.find<StorageRepository>();
  final TransactionRepository _transactionRepo =
      Get.find<TransactionRepository>();

  var queueTasks = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchTasks();

    // Tự động làm mới danh sách khi background sync xử lý (làm thay đổi trạng thái task)
    ever(offlineSyncService.queueUpdateTrigger, (_) {
      if (!isClosed) fetchTasks();
    });
  }

  Future<void> fetchTasks() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      final db = await _localDb.database;
      return await db.query(
        'offline_tasks_queue',
        orderBy: 'created_at DESC',
      );
    }, tag: "FETCH_OFFLINE_TASKS");

    result.fold(
      (failure) {
        showErrorMessage("Lỗi tải hàng đợi", failure.message);
      },
      (maps) {
        queueTasks.assignAll(maps);
      },
    );
    hideLoading();
  }

  List<String> get _validCategoryNames {
    return budgetService.activeCategoryGroups
        .expand((group) => group.categories)
        .map((budgetCat) => budgetCat.name)
        .toList();
  }

  Future<void> handleTaskTap(Map<String, dynamic> task) async {
    if (task['status'] != 'NEEDS_CONFIRMATION') return;

    final parsedDataStr = task['parsed_data'] as String?;
    if (parsedDataStr == null || parsedDataStr.isEmpty) return;

    final result = await ErrorHandler.execute(() async {
      final List<dynamic> rawData = jsonDecode(parsedDataStr);
      return rawData.cast<Map<String, dynamic>>();
    }, tag: "PARSE_JSON_TASK");

    result.fold(
      (failure) {
        showErrorMessage(
          "Lỗi dữ liệu",
          "Không thể đọc dữ liệu: ${failure.message}",
        );
      },
      (dataList) {
        final taskId = task['id'] as String;
        final payload = task['payload'] as String;
        final type = task['task_type'] as String;

        File? receiptImage;
        if (type == 'IMAGE') {
          receiptImage = File(payload);
        }

        String rawText = type == 'TEXT' ? payload : '[Giao dịch từ $type]';

        Get.bottomSheet(
          ConfirmMultipleTransactionsBottomSheet(
            aiParsedDataList: dataList,
            availableCategories: _validCategoryNames,
            unallocatedAmount: budgetService.unallocatedAmount.value,
            receiptImage: receiptImage,
            onConfirmAll: (confirmedDataList) async => await _saveTransactions(
              taskId,
              confirmedDataList,
              rawText: rawText,
              receiptImage: receiptImage,
            ),
          ),
          isScrollControlled: true,
        );
      },
    );
  }

  void _showSavingDialog() {
    Get.dialog(
      const LoadingDialogWidget(
        message: "Đang lưu giao dịch...",
        subMessage: "Đồng bộ dữ liệu lên hệ thống",
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _saveTransactions(
    String taskId,
    List<Map<String, dynamic>> confirmedDataList, {
    String rawText = '',
    File? receiptImage,
  }) async {
    _showSavingDialog();

    final saveResult = await ErrorHandler.execute(() async {
      List<String> receiptFileIds = [];
      if (receiptImage != null && await receiptImage.exists()) {
        receiptFileIds.add(receiptImage.path);
      }

      for (var confirmedData in confirmedDataList) {
        final catName = confirmedData['categoryName'];
        CategoryModel? category;
        if (catName != null) {
          final budgetCat = budgetService.categories.firstWhereOrNull(
            (c) => c.name == catName,
          );
          if (budgetCat != null) {
            category = budgetCat.categoryModel;
          }
        }

        final type = confirmedData['type'] == 'inflow' ? 'INCOME' : 'EXPENSE';
        final amount = (confirmedData['amount'] as num).toDouble();
        final note = confirmedData['note']?.toString() ?? '';
        final txDate = confirmedData['date'] as DateTime? ?? DateTime.now();

        final tx = TransactionModel(
          id: ID.unique(),
          categoryId: category?.id ?? '',
          amount: amount,
          type: type,
          transactionDate: txDate,
          status: 'COMPLETED',
          note: note,
        );

        final detail = TransactionDetailModel(
          id: ID.unique(),
          transactionId: tx.id,
          note: note,
          receiptFileIds: receiptFileIds,
          rawInputText: rawText,
          confidenceScore: (confirmedData['confidence'] ?? 0.8).toDouble(),
        );

        await _transactionRepo.createTransaction(
          transaction: tx,
          transactionDetail: detail,
          currentCategory: category,
        );
      }

      // Xóa task khỏi queue sau khi lưu thành công
      await _localDb.deleteTask(taskId);
    }, tag: "SAVE_CONFIRMED_TX");

    // Đóng Loading
    if (Get.isDialogOpen == true) Get.back();

    saveResult.fold(
      (failure) {
        showErrorMessage("Lỗi lưu giao dịch", failure.message);
      },
      (_) async {
        // Đóng BottomSheet
        if (Get.isBottomSheetOpen == true) Get.back();

        // Refresh UI
        budgetService.refreshData();
        offlineSyncService.refreshQueueCount();
        await fetchTasks();

        showSuccessMessage("Thành công", "Đã lưu các giao dịch thành công");
      },
    );
  }
}
