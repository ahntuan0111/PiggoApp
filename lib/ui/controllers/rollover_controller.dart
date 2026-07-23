import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:get/get.dart';
import 'package:appintern/domain/repositories/rollover_repository.dart';
import 'package:appintern/core/routes/app_pages.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:flutter/material.dart';

class RolloverController extends BaseController {
  final RolloverRepository rolloverRepository = Get.find<RolloverRepository>();
  final BudgetService budgetService = Get.find<BudgetService>();

  var currentState = RolloverState.noPending.obs;
  var lastActiveMonthYear = "".obs;

  // --- MOCK DATA Dành cho UI (Trong tương lai sẽ tính toán từ BudgetService) ---
  
  var isSurplus = true.obs;
  var balance = 0.0.obs;
  var income = 0.0.obs;
  var expense = 0.0.obs;
  var efficiency = 0.0.obs;
  
  // Thống kê Mini Card
  var biggestSavingTitle = "Chưa có".obs;
  var biggestSavingAmount = 0.0.obs;
  var biggestExpenseTitle = "Chưa có".obs;
  var biggestExpenseAmount = 0.0.obs;

  // Dữ liệu cho RolloverDecisionScreen
  var totalSurplus = 0.0.obs;
  var totalDeficit = 0.0.obs;
  var pendingCount = 0.obs;

  // Danh sách Hũ cần xử lý
  var decisionCategories = <Map<String, dynamic>>[].obs;

  // Dữ liệu cho NewMonthSetupScreen
  var expectedIncomeText = "".obs;
  var hasHardDeficit = false.obs;
  var deficitAmount = 0.0.obs;
  var clonedCategories = <Map<String, dynamic>>[].obs;

  // Dữ liệu cho MultiMonthGapScreen
  var currentMonthYear = "".obs;
  var totalGapBalance = 0.0.obs;

  var oldMonthName = "".obs;
  var newMonthName = "".obs;

  @override
  void onInit() {
    super.onInit();
    currentMonthYear.value = "Tháng ${DateTime.now().month}, ${DateTime.now().year}";
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args['state'] != null) {
        currentState.value = args['state'];
      }
      if (args['lastActiveMonthYear'] != null) {
        lastActiveMonthYear.value = args['lastActiveMonthYear'];
      }
    }
  }

  @override
  void onReady() {
    super.onReady();
    _loadRolloverData();
  }

  Future<void> _loadRolloverData() async {
    if (lastActiveMonthYear.value.isEmpty) return;

    if (lastActiveMonthYear.value.length == 7) {
      int oldM = int.tryParse(lastActiveMonthYear.value.substring(0, 2)) ?? 1;
      int oldY = int.tryParse(lastActiveMonthYear.value.substring(3)) ?? 2026;
      oldMonthName.value = "Tháng $oldM, $oldY";
      
      int newM = oldM == 12 ? 1 : oldM + 1;
      int newY = oldM == 12 ? oldY + 1 : oldY;
      newMonthName.value = "Tháng $newM, $newY";
    }

    showLoading();
    final result = await ErrorHandler.execute(() async {
      return await rolloverRepository.getRolloverData(
        budgetService.currentUserId.value,
        lastActiveMonthYear.value,
      );
    }, tag: "LOAD_ROLLOVER_DATA");
    hideLoading();

    result.fold(
      (failure) => showErrorMessage("Lỗi", failure.message),
      (data) {
        // --- 1. Month End Report ---
        double totalBudgeted = data.budgets.fold(0.0, (sum, b) => sum + b.budgetedAmount);

        if (data.summary != null) {
          income.value = totalBudgeted + data.summary!.totalIncome;
          expense.value = data.summary!.totalExpense;
        } else {
          income.value = totalBudgeted;
          expense.value = 0.0;
        }

        balance.value = income.value - expense.value;
        if (income.value > 0) {
          efficiency.value = (balance.value / income.value) * 100;
        } else {
          efficiency.value = 0.0;
        }
        isSurplus.value = balance.value >= 0;

        // --- 2. Rollover Decision ---
        double tSurplus = 0;
        double tDeficit = 0;
        List<Map<String, dynamic>> cats = [];
        for (var b in data.budgets) {
          final cat = data.categories.firstWhereOrNull((c) => c.id == b.categoryId);
          if (cat != null) {
            double remaining = (b.budgetedAmount + b.rolloverAmount) - b.spentAmount;
            if (remaining != 0) {
              cats.add({
                'id': cat.id,
                'title': cat.name,
                'icon': cat.iconName,
                'balance': remaining,
                'isSurplus': remaining > 0,
                'isExpanded': false.obs,
              });
              if (remaining > 0) {
                tSurplus += remaining;
              } else {
                tDeficit += remaining; // remaining is negative
              }
            }
          }
        }

        // --- Tìm Hũ Tiết kiệm lớn nhất & Chi lớn nhất ---
        Map<String, dynamic>? maxSavingCat;
        Map<String, dynamic>? maxExpenseCat;
        double maxSaving = -1;
        double maxExpense = -1;

        for (var b in data.budgets) {
          final cat = data.categories.firstWhereOrNull((c) => c.id == b.categoryId);
          if (cat != null) {
            double remaining = (b.budgetedAmount + b.rolloverAmount) - b.spentAmount;
            if (remaining > maxSaving) {
              maxSaving = remaining;
              maxSavingCat = {'title': cat.name, 'amount': remaining};
            }
            if (b.spentAmount > maxExpense && b.spentAmount > 0) {
              maxExpense = b.spentAmount;
              maxExpenseCat = {'title': cat.name, 'amount': b.spentAmount};
            }
          }
        }

        if (maxSavingCat != null && maxSaving > 0) {
          biggestSavingTitle.value = maxSavingCat['title'];
          biggestSavingAmount.value = maxSavingCat['amount'];
        } else {
          biggestSavingTitle.value = "Chưa có";
          biggestSavingAmount.value = 0.0;
        }

        if (maxExpenseCat != null && maxExpense > 0) {
          biggestExpenseTitle.value = maxExpenseCat['title'];
          biggestExpenseAmount.value = maxExpenseCat['amount'];
        } else {
          biggestExpenseTitle.value = "Chưa có";
          biggestExpenseAmount.value = 0.0;
        }

        totalSurplus.value = tSurplus;
        totalDeficit.value = tDeficit;
        decisionCategories.assignAll(cats);
        pendingCount.value = cats.length;

        // --- 3. New Month Setup (Logic Case 6) ---
        // Tiền có sẵn cho tháng mới (nếu không tạo budget nào) = Tổng tiền ví hiện tại - Tổng defaultBudget
        double totalDefaultBudgets = data.categories.fold(0.0, (sum, cat) => sum + cat.defaultBudget);
        double startingUnallocated = data.totalWalletBalance - totalDefaultBudgets;

        // Nếu bù đắp các khoản âm của tháng cũ mà vẫn âm -> Nợ Kỹ Thuật
        double finalUnallocated = startingUnallocated + tDeficit; 
        if (finalUnallocated < 0) {
          hasHardDeficit.value = true;
          deficitAmount.value = finalUnallocated;
        } else {
          hasHardDeficit.value = false;
          deficitAmount.value = 0;
        }

        clonedCategories.assignAll(data.categories.map((c) => {
          'id': c.id,
          'title': c.name,
          'icon': c.iconName,
          'budget': c.defaultBudget,
          'showAi': false,
        }).toList());

        // --- 4. Multi-month Gap ---
        totalGapBalance.value = data.totalWalletBalance;
      }
    );
  }

  // --- NAVIGATION & LOGIC METHODS ---

  void toggleCategoryExpand(int index) {
    var cat = decisionCategories[index];
    RxBool isExpanded = cat['isExpanded'] as RxBool;
    isExpanded.value = !isExpanded.value;
  }

  void onMassiveLazyAction() {
    // Nút Gom tất cả số dư
    pendingCount.value = 0;
    // Chuyển tất cả category về trạng thái đã xử lý (đóng lại)
    for (var cat in decisionCategories) {
      (cat['isExpanded'] as RxBool).value = false;
    }
  }

  void onStartRolloverDecision() {
    // Chuyển sang màn hình Step 2 (Quyết định xử lý số dư)
    Get.toNamed(Routes.ROLLOVER_DECISION);
  }

  void onFinishRolloverDecision() {
    if (pendingCount.value > 0) return;
    Get.toNamed(Routes.ROLLOVER_NEW_MONTH);
  }

  Future<void> onStartHardReset() async {
    // Bước cuối cùng, xử lý reset và vào tháng mới
    showLoading();
    final result = await ErrorHandler.execute(() async {
      await rolloverRepository.executeHardReset(
        budgetService.currentUserId.value,
      );
    }, tag: "HARD_RESET");
    hideLoading();

    result.fold((failure) => showErrorMessage("Lỗi", failure.message), (_) {
      budgetService.refreshData(); // Cập nhật lại dữ liệu tháng mới
      Get.offAllNamed(Routes.MAIN); // Về trang chủ
    });
  }

  void onExpectedIncomeChanged(String value) {
    expectedIncomeText.value = value;
  }
}
