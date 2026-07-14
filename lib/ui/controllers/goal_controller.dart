import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/domain/repositories/goal_repository.dart';
import 'package:get/get.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/budget_category.dart';

class GoalController extends BaseController with BudgetAware {
  final GoalRepository goalRepository = Get.find<GoalRepository>();

  final goals = <GoalModel>[].obs;
  
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

  @override
  void onInit() {
    super.onInit();
    fetchGoals();
  }

  Future<void> fetchGoals() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      return await goalRepository.getGoals();
    }, tag: "FETCH_GOALS");
    
    hideLoading();
    
    result.fold(
      (failure) => showErrorMessage("Lỗi tải mục tiêu", failure.message),
      (data) {
        final validCategoryIds = budgetService.categories.map((c) => c.categoryModel.id).toSet();
        final userGoals = data.where((g) => 
          validCategoryIds.contains(g.categoryId) && 
          g.name.trim().isNotEmpty && 
          g.targetAmount > 0
        ).toList();
        goals.assignAll(userGoals);
      }
    );
  }

  BudgetCategory? _getCategoryForGoal(String categoryId) {
    return budgetService.categories.firstWhereOrNull((c) => c.categoryModel.id == categoryId);
  }

  double getGoalProgress(GoalModel goal) {
    if (goal.targetAmount <= 0) return 0;
    final saved = getSavedAmount(goal);
    final progress = saved / goal.targetAmount;
    return progress > 1.0 ? 1.0 : progress;
  }

  double getSavedAmount(GoalModel goal) {
    final category = budgetService.categories.firstWhereOrNull((c) => c.categoryModel.id == goal.categoryId);
    return category?.remaining ?? 0.0;
  }
}
