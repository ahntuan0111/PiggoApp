import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/repositories/transfer_log_repository.dart';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';

class GoalDetailController extends BaseController with BudgetAware {
  final GoalRepository goalRepository = Get.find<GoalRepository>();
  final CategoryRepository categoryRepository = Get.find<CategoryRepository>();
  final TransactionRepository transactionRepository =
      Get.find<TransactionRepository>();
  final TransferLogRepository transferLogRepository =
      Get.find<TransferLogRepository>();

  late Rx<GoalModel> goal;
  final transactions = <Map<String, dynamic>>[].obs;

  // Progress computation
  double get currentProgress {
    if (goal.value.targetAmount <= 0) return 0.0;
    final saved = getSavedAmount(goal.value);
    final p = saved / goal.value.targetAmount;
    return p > 1.0 ? 1.0 : p;
  }

  double get savedAmount {
    return getSavedAmount(goal.value);
  }

  bool get hasDropped {
    // Nếu có bất kỳ lịch sử rút tiền nào, coi như bị tụt
    return transactions.any((t) => t['type'] == 'EXPENSE');
  }

  double get unallocatedAmount {
    return budgetService.unallocatedAmount.value;
  }

  @override
  void onInit() {
    super.onInit();
    final GoalModel args = Get.arguments;
    goal = args.obs;
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      final rawTransactions = await transactionRepository.getHistoryByCategory(
        goal.value.categoryId,
        limit: 100,
      );

      final transferLogs = await transferLogRepository
          .getTransferLogsByCategoryId(goal.value.categoryId, limit: 100);

      List<Map<String, dynamic>> displayList = [];

      // 1. Map transactions (rút/chi tiêu)
      for (var item in rawTransactions) {
        final tx = item['transaction'];
        final detail = item['detail'];

        displayList.add({
          'type': 'EXPENSE',
          'amount': tx.amount,
          'note': detail?.note ?? 'Rút quỹ',
          'date': tx.transactionDate,
          'walletName': 'Ngân sách',
          'categoryName': 'Chi tiêu', // Hoặc để trống, widget tự xử lý
        });
      }

      // 2. Map transfer logs (nạp tiền)
      for (var log in transferLogs) {
        bool isOutbound = goal.value.categoryId == log.fromCategoryId;
        if (!isOutbound) {
          // Tiền chuyển vào = Nạp ngân sách
          displayList.add({
            'type': 'INCOME', // giả lập loại nạp
            'amount': log.amount,
            'note': log.note ?? 'Nạp ngân sách tiết kiệm',
            'date': log.createdAt,
            'walletName': 'Ngân sách',
            'categoryName': 'Nạp tiền',
          });
        } else {
          // Tiền chuyển ra
          displayList.add({
            'type': 'EXPENSE',
            'amount': log.amount,
            'note': log.note ?? 'Rút ngân sách',
            'date': log.createdAt,
            'walletName': 'Ngân sách',
            'categoryName': 'Rút tiền',
          });
        }
      }

      // Sort theo thời gian mới nhất
      displayList.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );

      return displayList;
    }, tag: "FETCH_GOAL_HISTORY");

    hideLoading();

    result.fold(
      (failure) => showErrorMessage("Lỗi tải lịch sử", failure.message),
      (data) {
        transactions.assignAll(data);
      },
    );
  }

  /// Pull-to-Refresh: làm mới lịch sử và đồng bộ budget
  Future<void> refreshAll() async {
    await Future.wait([fetchHistory(), budgetService.refreshData()]);
  }

  Future<void> addUnallocatedToGoal() async {
    final amount = unallocatedAmount;
    if (amount <= 0) return;

    showLoading();
    final networkService = Get.find<NetworkService>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    
    if (networkService.isOffline.value && offlineSyncService.checkAndShowManualQueueFull()) {
      hideLoading();
      return;
    }
    
    final localDb = Get.find<LocalDatabaseService>();
    final now = budgetService.currentTrackingMonth.value;
    final monthYearStr = "${now.month.toString().padLeft(2, '0')}-${now.year}";

    final category = budgetService.categories
        .firstWhereOrNull((c) => c.categoryModel.id == goal.value.categoryId)
        ?.categoryModel;
    if (category == null) {
      hideLoading();
      return;
    }

    final newBudget = category.defaultBudget + amount;

    final allocations = [
      {'categoryId': category.id, 'amount': newBudget},
    ];

    final transferLogs = <Map<String, dynamic>>[];
    transferLogs.add({
      'amount': amount,
      'fromCategoryId': null,
      'toCategoryId': category.id,
      'note': 'Chuyển tiền nhàn rỗi',
    });

    if (networkService.isOffline.value) {
      final payload = jsonEncode({
        'monthYear': monthYearStr,
        'allocations': allocations,
        'transferLogs': transferLogs,
      });
      await offlineSyncService.queueManualTask('UPDATE_BUDGET', payload);
      await localDb.transferBudgetLocal(
        null,
        category.id,
        amount,
        monthYearStr,
        isOffline: true,
      );

      hideLoading();
      showSuccessMessage(
        "Đã lưu (Ngoại tuyến)",
        "Dữ liệu sẽ được đồng bộ khi có mạng",
      );
      await budgetService.refreshData();
      await fetchHistory();
    } else {
      final result = await ErrorHandler.execute(() async {
        await categoryRepository.transferBudget(
          monthYearStr,
          allocations,
          transferLogs: transferLogs,
        );
        await localDb.transferBudgetLocal(
          null,
          category.id,
          amount,
          monthYearStr,
          isOffline: false,
        );
      }, tag: "UPDATE_BUDGET");
      hideLoading();

      result.fold((failure) => showErrorMessage('Lỗi', failure.message), (
        _,
      ) async {
        showSuccessMessage(
          'Thành công',
          'Đã chuyển tiền nhàn rỗi vào mục tiêu!',
        );
        await budgetService.refreshData();
        await fetchHistory();
      });
    }
  }

  Future<bool> deleteGoal() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      final networkService = Get.find<NetworkService>();
      final offlineSyncService = Get.find<OfflineSyncService>();
      final localDb = Get.find<LocalDatabaseService>();
      final isOffline = networkService.isOffline.value;

      if (isOffline && offlineSyncService.checkAndShowManualQueueFull()) {
        return; // Dừng lại, ErrorHandler sẽ trả về data null và hideLoading()
      }

      if (isOffline) {
        // Xóa local db
        await localDb.deleteLocalGoal(goal.value.id);
        await localDb.deleteCategory(goal.value.categoryId);

        // Queue offline tasks
        final payload = jsonEncode({
          'goalId': goal.value.id,
          'categoryId': goal.value.categoryId,
        });
        await offlineSyncService.queueManualTask('DELETE_GOAL', payload);
      } else {
        // Xóa Goal trước vì Goal reference tới Category
        await goalRepository.deleteGoal(goal.value.id);
        // Xóa Category sau, logic xóa quan hệ đã được đưa vào CategoryRepository
        await categoryRepository.deleteCategory(goal.value.categoryId);
      }
    }, tag: "DELETE_GOAL");

    hideLoading();

    return result.fold(
      (failure) {
        showErrorMessage("Lỗi khi xóa mục tiêu", failure.message);
        return false;
      },
      (success) async {
        await budgetService.refreshData(); // Đồng bộ dữ liệu ngầm trước
        return true;
      },
    );
  }

  Future<bool> updateGoal(
    String newName,
    double newTarget,
    DateTime? newDeadline,
    String newIcon,
  ) async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      final networkService = Get.find<NetworkService>();
      final offlineSyncService = Get.find<OfflineSyncService>();
      final localDb = Get.find<LocalDatabaseService>();
      final isOffline = networkService.isOffline.value;

      if (isOffline && offlineSyncService.checkAndShowManualQueueFull()) {
        return;
      }

      // 1. Cập nhật Category
      final category = budgetService.categories.firstWhereOrNull(
        (c) => c.categoryModel.id == goal.value.categoryId,
      );

      Map<String, dynamic>? categoryUpdateMap;

      if (category != null) {
        if (isOffline) {
          final catModel = category.categoryModel;
          final updatedCat = CategoryModel(
            id: catModel.id,
            categoryTypeId: catModel.categoryTypeId,
            name: newName,
            color: catModel.color,
            iconName: newIcon,
            defaultBudget: catModel.defaultBudget,
            isActive: catModel.isActive,
            spent: catModel.spent,
          );
          await localDb.updateCategory(
            catModel.id,
            newName,
            newIcon,
            catModel.color,
          );
          categoryUpdateMap = {
            'id': catModel.id,
            'name': newName,
            'iconName': newIcon,
            'color': catModel.color,
          };
        } else {
          await categoryRepository.updateCategory(
            category.categoryModel.id,
            newName,
            newIcon,
            category.categoryModel.color,
          );
        }
      }

      // 2. Cập nhật Goal
      String newStatus = goal.value.status;
      if (newStatus == 'COMPLETED' && newTarget > getSavedAmount(goal.value)) {
        newStatus = 'ACTIVE';
      }

      final updatedGoal = goal.value.copyWith(
        name: newName,
        targetAmount: newTarget,
        deadline: newDeadline,
        status: newStatus,
      );

      if (isOffline) {
        final goalMap = updatedGoal.toMap()..['id'] = updatedGoal.id;
        await localDb.updateLocalGoal(goalMap);
        final payload = jsonEncode({
          'goal': goalMap,
          if (categoryUpdateMap != null) 'categoryUpdate': categoryUpdateMap,
        });
        await offlineSyncService.queueManualTask('UPDATE_GOAL', payload);
        goal.value = updatedGoal;
      } else {
        final savedGoal = await goalRepository.updateGoal(updatedGoal);
        goal.value = savedGoal;
      }
    }, tag: "UPDATE_GOAL");

    hideLoading();

    return result.fold(
      (failure) {
        showErrorMessage("Lỗi khi cập nhật mục tiêu", failure.message);
        return false;
      },
      (success) {
        showSuccessMessage("Thành công", "Đã cập nhật mục tiêu tiết kiệm");
        budgetService.refreshData(); // Đồng bộ lại category thay đổi
        return true;
      },
    );
  }

  double getSavedAmount(GoalModel goalItem) {
    final category = budgetService.categories.firstWhereOrNull(
      (c) => c.categoryModel.id == goalItem.categoryId,
    );
    return category?.remaining ?? 0.0;
  }
}
