import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:get/get.dart';

class GoalDetailController extends BaseController with BudgetAware {
  final GoalRepository goalRepository = Get.find<GoalRepository>();
  final CategoryRepository categoryRepository = Get.find<CategoryRepository>();
  final TransactionRepository transactionRepository =
      Get.find<TransactionRepository>();

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
      return await transactionRepository.getHistoryByCategory(
        goal.value.categoryId,
        limit: 100,
      );
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

  Future<void> deleteGoal() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      // Xóa Goal trước vì Goal reference tới Category
      await goalRepository.deleteGoal(goal.value.id);
      // Xóa Category sau, logic xóa quan hệ đã được đưa vào CategoryRepository
      await categoryRepository.deleteCategory(goal.value.categoryId);
    }, tag: "DELETE_GOAL");

    hideLoading();

    result.fold(
      (failure) => showErrorMessage("Lỗi khi xóa mục tiêu", failure.message),
      (success) async {
        Get.back(result: true); // Đóng màn hình chi tiết trước
        showSuccessMessage("Thành công", "Đã xóa mục tiêu tiết kiệm");
        await budgetService.refreshData(); // Đồng bộ dữ liệu ngầm
      },
    );
  }

  Future<void> updateGoal(
    String newName,
    double newTarget,
    DateTime? newDeadline,
    String newIcon,
  ) async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      // 1. Cập nhật Category
      final category = budgetService.categories.firstWhereOrNull(
        (c) => c.categoryModel.id == goal.value.categoryId,
      );
      if (category != null) {
        await categoryRepository.updateCategory(
          category.categoryModel.id,
          newName,
          newIcon,
          category.categoryModel.color,
        );
      }

      // 2. Cập nhật Goal
      final updatedGoal = goal.value.copyWith(
        name: newName,
        targetAmount: newTarget,
        deadline: newDeadline,
      );
      final savedGoal = await goalRepository.updateGoal(updatedGoal);
      goal.value = savedGoal;
    }, tag: "UPDATE_GOAL");

    hideLoading();

    result.fold(
      (failure) =>
          showErrorMessage("Lỗi khi cập nhật mục tiêu", failure.message),
      (success) {
        showSuccessMessage("Thành công", "Đã cập nhật mục tiêu tiết kiệm");
        budgetService.refreshData(); // Đồng bộ lại category thay đổi
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
