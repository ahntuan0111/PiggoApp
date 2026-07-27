import 'dart:async';
import 'package:get/get.dart';
import 'package:appintern/core/utils/logger.dart';
import 'package:appintern/data/models/budget_category_group.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:appintern/domain/repositories/goal_repository.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/models/monthly_budget_model.dart';
import 'package:appintern/core/errors/error_handler.dart';

class BudgetService extends GetxService {
  final StorageService storage = Get.find<StorageService>();
  final CategoryRepository categoryRepository = Get.find<CategoryRepository>();
  final TransactionRepository transactionRepository =
      Get.find<TransactionRepository>();
  final GoalRepository goalRepository = Get.find<GoalRepository>();

  var currentUserId = "".obs;
  var currentTrackingMonth = DateTime.now().obs;

  final totalWalletBalance = 0.0.obs;
  final allocatedAmount = 0.0.obs;
  final unallocatedAmount = 0.0.obs;

  final categories = <BudgetCategory>[].obs;
  final categoryGroups = <BudgetCategoryGroup>[].obs;
  final goals = <GoalModel>[].obs;
  final monthlyBudgets = <MonthlyBudgetModel>[].obs;

  var isDataLoaded = false.obs;
  var isError = false.obs;
  var errorMessage = "".obs;

  StreamSubscription? _txSubscription;

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = storage.read(AppKeys.userId) ?? "";

    // Listen to transaction updates
    _txSubscription = transactionRepository.onTransactionUpdated.listen((_) {
      refreshData();
    });
  }

  Future<void> refreshData() async {
    // Luôn đọc lại userId phòng trường hợp vừa login xong
    currentUserId.value = storage.read(AppKeys.userId) ?? "";
    final userId = currentUserId.value;

    if (userId.isEmpty) {
      isError.value = true;
      errorMessage.value = "Người dùng chưa đăng nhập";
      // Đánh dấu loaded để tránh kẹt loading ở HomeController
      isDataLoaded.value = true;
      return;
    }

    final result = await ErrorHandler.execute(() async {
      final types = await categoryRepository.getCategoryTypes(userId);
      List<BudgetCategoryGroup> tempGroups = [];
      List<BudgetCategory> tempCategories = [];

      if (types.isNotEmpty) {
        final typeIds = types.map((e) => e.id).toList();
        final cats = await categoryRepository.getCategories(typeIds);

        String monthYearStr =
            "${currentTrackingMonth.value.month.toString().padLeft(2, '0')}-${currentTrackingMonth.value.year}";
        final fetchedMonthlyBudgets = await categoryRepository.getMonthlyBudgets(
          monthYearStr,
        );
        monthlyBudgets.value = fetchedMonthlyBudgets;

        for (var type in types) {
          final typeCats = cats
              .where((c) => c.categoryTypeId == type.id)
              .toList();
          if (typeCats.isNotEmpty) {
            tempGroups.add(
              BudgetCategoryGroup(
                type.id,
                type.name,
                typeCats.map((c) {
                  final mb = fetchedMonthlyBudgets.firstWhereOrNull(
                    (m) => m.categoryId == c.id,
                  );
                  return BudgetCategory(
                    categoryModel: c,
                    icon: c.iconName,
                    name: c.name,
                    allocated: (mb?.budgetedAmount ?? 0.0) + (mb?.rolloverAmount ?? 0.0),
                    spent: mb?.spentAmount ?? 0.0,
                  );
                }).toList(),
              ),
            );
          }
        }
        tempCategories = tempGroups.expand((g) => g.categories).toList();
      }

      final fetchedGoals = await goalRepository.getGoals();

      // Lấy tất cả MonthlySummaries của user để tính dòng tiền
      final allSummaries = await categoryRepository.getAllMonthlySummaries();

      categoryGroups.value = tempGroups;
      categories.value = tempCategories;

      // Filter goals exactly as previously done in GoalController
      final validCategoryIds = tempCategories
          .map((c) => c.categoryModel.id)
          .toSet();
      final userGoals = fetchedGoals
          .where(
            (g) =>
                validCategoryIds.contains(g.categoryId) &&
                g.name.trim().isNotEmpty &&
                g.targetAmount > 0,
          )
          .toList();
      goals.value = userGoals;

      // Tính tổng Thu, tổng Chi của tất cả các tháng
      double totalAllTimeIncome = allSummaries.fold(0.0, (sum, s) => sum + s.totalIncome);
      double totalAllTimeExpense = allSummaries.fold(0.0, (sum, s) => sum + s.totalExpense);

      // Tổng ngân sách hiện tại = Tổng Thu - Tổng Chi
      totalWalletBalance.value = totalAllTimeIncome - totalAllTimeExpense;

      double totalRemainingBudgets = tempCategories.fold(
        0.0,
        (sum, c) => sum + (c.allocated - c.spent),
      );

      allocatedAmount.value = totalRemainingBudgets;
      
      // Số tiền chưa phân bổ = Tổng ngân sách - Tổng đã phân bổ (còn lại)
      unallocatedAmount.value = totalWalletBalance.value - totalRemainingBudgets;
    }, tag: "FETCH_BUDGET_DATA");

    result.fold(
      (failure) {
        AppLogger.error("FETCH_BUDGET_DATA", failure.message);
        isError.value = true;
        errorMessage.value = failure.message;
      },
      (_) {
        isError.value = false;
        errorMessage.value = "";
        isDataLoaded.value = true;
      },
    );
  }

  MonthlyBudgetModel? getBudgetForCategory(String categoryId) {
    return monthlyBudgets.firstWhereOrNull((m) => m.categoryId == categoryId);
  }

  @override
  void onClose() {
    _txSubscription?.cancel();
    super.onClose();
  }
}
