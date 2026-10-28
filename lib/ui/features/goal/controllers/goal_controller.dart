import 'dart:convert';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:get/get.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/ui/widgets/dialogs/celebration_dialog_widget.dart';
import 'package:appintern/data/repositories/goal_repository.dart';

class GoalController extends BaseController with BudgetAware {
  final CategoryRepository _categoryRepo = Get.find<CategoryRepository>();
  // Không cần GoalRepository nữa vì BudgetService đã quản lý

  // Proxy state từ BudgetService sang Controller
  List<GoalModel> get goals => budgetService.goals;

  // Tổng quan tiết kiệm
  double get totalSaved {
    double total = 0.0;
    for (var goal in goals) {
      final category = _getCategoryForGoal(goal.categoryId);
      if (category != null) {
        // Lấy số dư hiện tại của category
        total += category.remaining;
      }
    }
    return total;
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
    final now = budgetService.currentTrackingMonth.value;
    final monthYearStr = "${now.month.toString().padLeft(2, '0')}-${now.year}";

    final result = await ErrorHandler.execute(() async {
      final allocations = [
        {'categoryId': category.categoryModel.id, 'amount': newBudget},
        if (sourceCategoryId != null &&
            sourceCategoryId != 'unallocated' &&
            sourceCategoryNewBudget != null)
          {'categoryId': sourceCategoryId, 'amount': sourceCategoryNewBudget},
      ];

      double currentBudget =
          budgetService
              .getBudgetForCategory(category.categoryModel.id)
              ?.budgetedAmount ??
          category.categoryModel.defaultBudget;
      double amountChange = newBudget - currentBudget;

      final transferLogs = <Map<String, dynamic>>[];
      if (amountChange > 0) {
        transferLogs.add({
          'amount': amountChange,
          'fromCategoryId':
              (sourceCategoryId == null || sourceCategoryId == 'unallocated')
              ? null
              : sourceCategoryId,
          'toCategoryId': category.categoryModel.id,
          'note': note ?? 'Chuyển tiền mục tiêu',
        });
      } else if (amountChange < 0) {
        transferLogs.add({
          'amount': -amountChange,
          'fromCategoryId': category.categoryModel.id,
          'toCategoryId':
              (sourceCategoryId == null || sourceCategoryId == 'unallocated')
              ? null
              : sourceCategoryId,
          'note': note ?? 'Rút tiền mục tiêu',
        });
      }

      await _categoryRepo.transferBudget(
        monthYearStr,
        allocations,
        transferLogs: transferLogs,
      );

      final mbGoal = budgetService.getBudgetForCategory(category.categoryModel.id);
      if (mbGoal != null) {
        await _categoryRepo.updateMonthlyBudget(mbGoal.id, newBudget);
      } else {
        await _categoryRepo.createMonthlyBudget(
          categoryId: category.categoryModel.id,
          monthYear: monthYearStr,
          budgetedAmount: newBudget,
        );
      }

      if (sourceCategoryId != null &&
          sourceCategoryId != 'unallocated' &&
          sourceCategoryNewBudget != null) {
        final mbSource = budgetService.getBudgetForCategory(sourceCategoryId);
        if (mbSource != null) {
          await _categoryRepo.updateMonthlyBudget(
            mbSource.id,
            sourceCategoryNewBudget,
          );
        } else {
          await _categoryRepo.createMonthlyBudget(
            categoryId: sourceCategoryId,
            monthYear: monthYearStr,
            budgetedAmount: sourceCategoryNewBudget,
          );
        }
      }
    }, tag: "UPDATE_GOAL_BUDGET");

    hideLoading();
    result.fold((failure) => showErrorMessage('Lỗi', failure.message), (
      _,
    ) async {
      await budgetService.loadDataFromLocal();

      final goal = goals.firstWhereOrNull(
        (g) => g.categoryId == category.categoryModel.id,
      );
      bool justCompleted = false;
      if (goal != null && goal.status != 'COMPLETED') {
        if (getSavedAmount(goal) >= goal.targetAmount) {
          await _completeGoal(goal);
          justCompleted = true;
        }
      }

      if (justCompleted) {
        _showCelebrationDialog();
      } else {
        showSuccessMessage('Thành công', 'Đã nạp tiền vào mục tiêu!');
      }
    });
  }

  Future<void> _completeGoal(GoalModel goal) async {
    final updatedGoal = goal.copyWith(status: 'COMPLETED');
    final repo = Get.find<GoalRepository>();
    final result = await ErrorHandler.execute(() async {
      await repo.updateGoal(updatedGoal);
    }, tag: "COMPLETE_GOAL");

    if (result.isRight()) {
      final localDb = Get.find<LocalDatabaseService>();
      await localDb.updateLocalGoal(updatedGoal.toMap());
    }

    await budgetService.refreshData();
  }

  void _showCelebrationDialog() {
    // Để gọi confetti, ta mở một dialog có chứa confetti widget
    Get.dialog(
      const CelebrationDialogWidget(
        title: "🎉 Xin chúc mừng! 🎉",
        message: "Bạn đã hoàn thành mục tiêu tiết kiệm này!",
      ),
      barrierDismissible: false,
    );
  }
}
