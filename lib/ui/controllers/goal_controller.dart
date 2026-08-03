import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/transfer_log_repository.dart';
import 'package:appintern/data/models/transfer_log_model.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:get/get.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/core/services/network_service.dart';

class GoalController extends BaseController with BudgetAware {
  final CategoryRepository _categoryRepo = Get.find<CategoryRepository>();
  final TransferLogRepository _transferLogRepo =
      Get.find<TransferLogRepository>();
  final StorageService _storage = Get.find<StorageService>();
  // Không cần GoalRepository nữa vì BudgetService đã quản lý

  // Proxy state từ BudgetService sang Controller
  List<GoalModel> get goals => budgetService.goals;

  // Tổng quan tiết kiệm
  RxDouble get totalSaved {
    double total = 0.0;
    for (var goal in goals) {
      final category = _getCategoryForGoal(goal.categoryId);
      if (category != null) {
        // Lấy số dư hiện tại của category
        total += category.remaining ?? 0.0;
      }
    }
    return total.obs;
  }

  // Hàm reload (chỉ gọi proxy tới BudgetService)
  Future<void> fetchGoals() async {
    await budgetService.refreshData();
  }

  BudgetCategory? _getCategoryForGoal(String categoryId) {
    return budgetService.categories.firstWhereOrNull(
      (c) => c.categoryModel.id == categoryId,
    );
  }

  double getGoalProgress(GoalModel goal) {
    if (goal.targetAmount <= 0) return 0;
    final saved = getSavedAmount(goal);
    final progress = saved / goal.targetAmount;
    return progress > 1.0 ? 1.0 : progress;
  }

  double getSavedAmount(GoalModel goal) {
    final category = budgetService.categories.firstWhereOrNull(
      (c) => c.categoryModel.id == goal.categoryId,
    );
    return category?.remaining ?? 0.0;
  }

  Future<void> updateGoalBudget(
    BudgetCategory category,
    double newBudget, {
    String? sourceCategoryId,
    double? sourceCategoryNewBudget,
    String? note,
  }) async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      final now = budgetService.currentTrackingMonth.value;
      final monthYearStr =
          "${now.month.toString().padLeft(2, '0')}-${now.year}";

      final mbTarget = budgetService.getBudgetForCategory(
        category.categoryModel.id,
      );
      if (mbTarget != null) {
        await _categoryRepo.updateMonthlyBudget(mbTarget.id, newBudget);
      } else {
        await _categoryRepo.createMonthlyBudget(
          categoryId: category.categoryModel.id,
          monthYear: monthYearStr,
          budgetedAmount: newBudget,
        );
      }

      // Cập nhật category nguồn (nếu có và không phải là 'unallocated')
      if (sourceCategoryId != null &&
          sourceCategoryId != 'unallocated' &&
          sourceCategoryNewBudget != null) {
        final sourceCatList = budgetService.categories
            .where((c) => c.categoryModel.id == sourceCategoryId)
            .toList();

        if (sourceCatList.isNotEmpty) {
          final sourceCat = sourceCatList.first.categoryModel;
          final mbSource = budgetService.getBudgetForCategory(sourceCat.id);
          if (mbSource != null) {
            await _categoryRepo.updateMonthlyBudget(
              mbSource.id,
              sourceCategoryNewBudget,
            );
          } else {
            await _categoryRepo.createMonthlyBudget(
              categoryId: sourceCat.id,
              monthYear: monthYearStr,
              budgetedAmount: sourceCategoryNewBudget,
            );
          }
        }
      }

      // Ghi log chuyển ngân sách
      String userId = _storage.read<String>(AppKeys.userId) ?? '';
      double amountMoved = (newBudget - category.categoryModel.defaultBudget)
          .abs();
      String fromCat = sourceCategoryId ?? 'unallocated';
      String toCat = category.categoryModel.id;

      if (newBudget < category.categoryModel.defaultBudget) {
        // Rút tiền khỏi Goal
        fromCat = category.categoryModel.id;
        toCat = sourceCategoryId ?? 'unallocated';
      }

      final log = TransferLogModel(
        id: '',
        ownerId: userId,
        amount: amountMoved,
        fromCategoryId: fromCat,
        toCategoryId: toCat,
        note: note,
        createdAt: DateTime.now(),
      );

      await _transferLogRepo.createTransferLog(log);
    }, tag: "UPDATE_GOAL_BUDGET");

    hideLoading();
    result.fold((failure) => showErrorMessage('Lỗi', failure.message), (
      _,
    ) async {
      await budgetService.refreshData();
      final isOffline = Get.find<NetworkService>().isOffline.value;
      if (isOffline) {
        showSuccessMessage('Đã lưu (Ngoại tuyến)', 'Dữ liệu sẽ được đồng bộ khi có mạng');
      } else {
        showSuccessMessage('Thành công', 'Đã nạp tiền vào mục tiêu!');
      }
    });
  }
}
