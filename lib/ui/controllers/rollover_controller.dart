import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:get/get.dart';
import 'package:appintern/domain/repositories/rollover_repository.dart';
import 'package:appintern/core/routes/app_pages.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:flutter/material.dart';
import 'package:appintern/ui/widgets/dialogs/rollover_explanation_dialog.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';

enum RolloverOption {
  sweepToSavings, // Tiết kiệm
  rolloverToCategory, // Cộng dồn
  reduceBudget, // Giảm ĐM
  sweepToUnallocated, // Chuyển DP / Trừ DP
}

class RolloverController extends BaseController {
  final RolloverRepository rolloverRepository = Get.find<RolloverRepository>();
  final BudgetService budgetService = Get.find<BudgetService>();

  var currentState = RolloverState.noPending.obs;
  var lastActiveMonthYear = "".obs;

  // --- MOCK DATA Dành cho UI (Trong tương lai sẽ tính toán từ BudgetService) ---

  var isSurplus = true.obs;
  // Dữ liệu cho MonthEndReportScreen
  var income = 0.0.obs;
  var expense = 0.0.obs;
  var balance = 0.0.obs;
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
  var totalAllocatedAmount = 0.0.obs;
  var clonedCategories = <Map<String, dynamic>>[].obs;

  // Dữ liệu cho MultiMonthGapScreen
  var currentMonthYear = "".obs;
  var totalGapBalance = 0.0.obs;

  var oldMonthName = "".obs;
  var newMonthName = "".obs;

  dynamic get activeGoal {
    if (budgetService.goals.isEmpty) return null;
    
    int newM = DateTime.now().month;
    int newY = DateTime.now().year;

    if (lastActiveMonthYear.value.length == 7) {
      int oldM = int.tryParse(lastActiveMonthYear.value.substring(0, 2)) ?? newM;
      int oldY = int.tryParse(lastActiveMonthYear.value.substring(3)) ?? newY;

      newM = oldM == 12 ? 1 : oldM + 1;
      newY = oldM == 12 ? oldY + 1 : oldY;
    }

    final startOfNewMonth = DateTime(newY, newM, 1);

    return budgetService.goals.firstWhereOrNull((goal) {
      if (goal.deadline == null) return true;
      // Goal phải có deadline >= ngày đầu tiên của tháng mới
      return goal.deadline!.isAfter(startOfNewMonth.subtract(const Duration(days: 1)));
    });
  }

  bool get hasActiveGoals => activeGoal != null;

  @override
  void onInit() {
    super.onInit();
    currentMonthYear.value =
        "Tháng ${DateTime.now().month}, ${DateTime.now().year}";
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

    result.fold((failure) => showErrorMessage("Lỗi", failure.message), (data) {
      // --- 1. Month End Report ---
      if (data.summary != null) {
        income.value = data.summary!.totalIncome;
        expense.value = data.summary!.totalExpense;
      } else {
        income.value = 0.0;
        expense.value = 0.0;
      }

      // Số dư tháng qua = Thu - Chi
      balance.value = income.value - expense.value;

      // Hiệu suất: Dựa trên tổng lượng tiền vào
      double totalInflow = income.value;
      if (totalInflow > 0) {
        efficiency.value = (balance.value / totalInflow) * 100;
      } else {
        efficiency.value = 0.0;
      }
      isSurplus.value = balance.value >= 0;

      // --- 2. Rollover Decision ---
      double tSurplus = 0;
      double tDeficit = 0;
      List<Map<String, dynamic>> cats = [];

      bool hasGoals = hasActiveGoals;

      for (var b in data.budgets) {
        final cat = data.categories.firstWhereOrNull(
          (c) => c.id == b.categoryId,
        );
        if (cat != null) {
          double remaining =
              (b.budgetedAmount + b.rolloverAmount) - b.spentAmount;
          if (remaining != 0) {
            cats.add({
              'id': cat.id,
              'title': cat.name,
              'icon': cat.iconName,
              'balance': remaining,
              'isSurplus': remaining > 0,
              'isExpanded': false.obs,
              'selectedOption': RolloverOption.sweepToUnallocated.obs,
              'isProcessed': false.obs,
              'isGoalAvailable': hasGoals,
              'isUnallocatedItem': false,
            });
            if (remaining > 0) {
              tSurplus += remaining;
            } else {
              tDeficit += remaining; // remaining is negative
            }
          }
        }
      }

      // Thêm cục "Quỹ chưa phân bổ" lên đầu danh sách
      // SỬA LỖI QUAN TRỌNG: Quỹ chưa phân bổ phải bằng = TỔNG TIỀN TRONG VÍ - TỔNG TIỀN TRONG CÁC HŨ.
      // Không được dùng balance.value (vì balance.value chỉ là Thu - Chi của 1 tháng, sẽ làm mất tiền chưa phân bổ từ tháng trước).
      double actualUnallocated = budgetService.totalWalletBalance.value - (tSurplus + tDeficit);
      if (actualUnallocated > 0) {
        cats.insert(0, {
          'id': 'unallocated_pool',
          'title': 'Quỹ chưa phân bổ',
          'icon': 'icon_wallet.png',
          'balance': actualUnallocated,
          'isSurplus': true, // Luôn dương
          'isExpanded': false.obs,
          'selectedOption': RolloverOption.sweepToUnallocated.obs,
          'isProcessed': false.obs,
          'isGoalAvailable': hasGoals,
          'isUnallocatedItem': true,
        });
        tSurplus += actualUnallocated;
      }
      // Không cộng actualUnallocated âm vào tDeficit nữa để tránh gây hiểu lầm cho người dùng
      // (người dùng chỉ muốn thấy thâm hụt nếu có Category thực sự bị âm).

      // --- Tìm Hũ Tiết kiệm lớn nhất & Chi lớn nhất ---
      Map<String, dynamic>? maxSavingCat;
      Map<String, dynamic>? maxExpenseCat;
      double maxSaving = -1;
      double maxExpense = -1;

      for (var b in data.budgets) {
        final cat = data.categories.firstWhereOrNull(
          (c) => c.id == b.categoryId,
        );
        if (cat != null) {
          double remaining =
              (b.budgetedAmount + b.rolloverAmount) - b.spentAmount;
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
      double totalDefaultBudgets = data.categories.fold(
        0.0,
        (sum, cat) => sum + cat.defaultBudget,
      );
      totalAllocatedAmount.value = totalDefaultBudgets;

      clonedCategories.assignAll(
        data.categories
            .map(
              (c) => {
                'id': c.id,
                'title': c.name,
                'icon': c.iconName,
                'budget': c.defaultBudget,
                'showAi': false,
              },
            )
            .toList(),
      );

      // --- 4. Multi-month Gap ---
      totalGapBalance.value = budgetService.totalWalletBalance.value;
    });
  }

  // --- NAVIGATION & LOGIC METHODS ---

  void _updatePendingCount() {
    pendingCount.value = decisionCategories
        .where((c) => !(c['isProcessed'] as RxBool).value)
        .length;
  }

  void selectOption(int index, RolloverOption option) {
    var cat = decisionCategories[index];
    (cat['selectedOption'] as Rx<RolloverOption>).value = option;
    (cat['isProcessed'] as RxBool).value = true;
    _updatePendingCount();
  }

  void toggleCategoryExpand(int index) {
    var cat = decisionCategories[index];
    RxBool isExpanded = cat['isExpanded'] as RxBool;
    isExpanded.value = !isExpanded.value;

    // Nếu mở ra thì cũng đánh dấu là đã chạm vào (nhưng UX tốt hơn là đánh dấu processed)
    (cat['isProcessed'] as RxBool).value = true;
    _updatePendingCount();
  }

  void onMassiveLazyAction() {
    // Chuyển tất cả category về trạng thái đã xử lý và chọn mặc định
    for (var cat in decisionCategories) {
      (cat['selectedOption'] as Rx<RolloverOption>).value =
          RolloverOption.sweepToUnallocated;
      (cat['isProcessed'] as RxBool).value = true;
      (cat['isExpanded'] as RxBool).value = false;
    }
    _updatePendingCount();
  }

  void onStartRolloverDecision() {
    // Chuyển sang màn hình Step 2 (Quyết định xử lý số dư)
    Get.toNamed(Routes.ROLLOVER_DECISION);

    // Hiển thị Dialog giải thích thuật ngữ sau khi chuyển màn hình
    Future.delayed(const Duration(milliseconds: 300), () {
      Get.dialog(const RolloverExplanationDialog());
    });
  }

  void onFinishRolloverDecision() {
    if (pendingCount.value > 0) return;
    Get.toNamed(Routes.ROLLOVER_NEW_MONTH);
  }

  Future<void> onStartHardReset() async {
    // Bước cuối cùng, xử lý phân bổ và vào tháng mới
    showLoading();
    final result = await ErrorHandler.execute(() async {
      Map<String, double> updatedBudgets = {};
      for (var cat in clonedCategories) {
        updatedBudgets[cat['id']] = (cat['budget'] as num).toDouble();
      }

      double totalCarryoverSurplus = 0.0;
      Map<String, double> rolloverAmounts = {};
      final currentActiveGoal = activeGoal;
      
      for (var cat in decisionCategories) {
        double balance = (cat['balance'] as num).toDouble();
        RolloverOption option = (cat['selectedOption'] as Rx<RolloverOption>).value;
        
        if (cat['isUnallocatedItem'] == true) {
          if (option == RolloverOption.sweepToSavings && currentActiveGoal != null) {
            String goalId = currentActiveGoal.categoryId;
            rolloverAmounts[goalId] = (rolloverAmounts[goalId] ?? 0.0) + balance;
          }
          if (balance > 0) totalCarryoverSurplus += balance;
          continue;
        }

        String id = cat['id'];

        if (option == RolloverOption.sweepToSavings && currentActiveGoal != null) {
          String goalId = currentActiveGoal.categoryId;
          rolloverAmounts[goalId] = (rolloverAmounts[goalId] ?? 0.0) + balance;
          rolloverAmounts[id] = 0.0;
          if (balance > 0) totalCarryoverSurplus += balance;
        } else if (option == RolloverOption.rolloverToCategory) {
          rolloverAmounts[id] = balance; // surplus
          if (balance > 0) totalCarryoverSurplus += balance;
        } else if (option == RolloverOption.sweepToUnallocated) {
          rolloverAmounts[id] = 0.0;
          if (balance > 0) totalCarryoverSurplus += balance;
        } else if (option == RolloverOption.reduceBudget) {
          rolloverAmounts[id] = balance; // deficit (negative)
        } else {
          rolloverAmounts[id] = 0.0;
        }
      }

      await rolloverRepository.executeRollover(
        budgetService.currentUserId.value,
        updatedBudgets,
        rolloverAmounts,
      );

      final txRepo = Get.find<TransactionRepository>();
      final now = DateTime.now();

      // --- 1. Xử lý tạo cặp giao dịch chuyển giao (Double-entry) ---
      if (totalCarryoverSurplus > 0) {
        int oldM = 1;
        int oldY = 2026;
        if (lastActiveMonthYear.value.length == 7) {
          oldM = int.tryParse(lastActiveMonthYear.value.substring(0, 2)) ?? 1;
          oldY = int.tryParse(lastActiveMonthYear.value.substring(3)) ?? 2026;
        }
        
        // Ngày cuối cùng của tháng cũ
        final lastDayOfOldMonth = DateTime(oldY, oldM + 1, 0, 23, 59, 59);

        final outcomeTx = TransactionModel(
          id: '',
          categoryId: '',
          amount: totalCarryoverSurplus,
          type: 'OUTCOME',
          transactionDate: lastDayOfOldMonth,
          status: 'COMPLETED',
          note: 'Chuyển số dư sang tháng ${now.month}',
        );

        final outcomeDetail = TransactionDetailModel(
          id: '',
          transactionId: '',
          note: 'Chuyển số dư sang tháng ${now.month}',
          receiptFileIds: [],
          rawInputText: '',
          confidenceScore: 1.0,
        );

        await txRepo.createWalletAdjustmentTransaction(
          transaction: outcomeTx,
          transactionDetail: outcomeDetail,
        );

        // Ngày mùng 1 tháng mới (lúc 07:59:59 để trước giao dịch ngân sách ban đầu 08:00:00)
        final firstDayOfNewMonth = DateTime(now.year, now.month, 1, 7, 59, 59);

        final incomeTx = TransactionModel(
          id: '',
          categoryId: '',
          amount: totalCarryoverSurplus,
          type: 'INCOME',
          transactionDate: firstDayOfNewMonth,
          status: 'COMPLETED',
          note: 'Nhận số dư từ tháng $oldM',
        );

        final incomeDetail = TransactionDetailModel(
          id: '',
          transactionId: '',
          note: 'Nhận số dư từ tháng $oldM',
          receiptFileIds: [],
          rawInputText: '',
          confidenceScore: 1.0,
        );

        await txRepo.createWalletAdjustmentTransaction(
          transaction: incomeTx,
          transactionDetail: incomeDetail,
        );
      }

      // --- 2. Tự động tạo giao dịch "Ngân sách ban đầu" ---
      String incomeStr = expectedIncomeText.value
          .replaceAll('.', '')
          .replaceAll(',', '')
          .replaceAll('đ', '')
          .trim();
      double expectedIncome = double.tryParse(incomeStr) ?? 0.0;

      if (expectedIncome > 0) {
        final firstDayOfMonth = DateTime(now.year, now.month, 1, 8, 0, 0);

        final transaction = TransactionModel(
          id: '',
          categoryId: '', // Wallet Adjustment không cần category
          amount: expectedIncome,
          type: 'INCOME',
          transactionDate: firstDayOfMonth,
          status: 'COMPLETED',
          note: 'Ngân sách ban đầu tháng ${now.month}',
        );

        final detail = TransactionDetailModel(
          id: '',
          transactionId: '',
          note: 'Ngân sách tháng ${now.month}',
          receiptFileIds: [],
          rawInputText: '',
          confidenceScore: 1.0,
        );

        await txRepo.createWalletAdjustmentTransaction(
          transaction: transaction,
          transactionDetail: detail,
        );
      }
    }, tag: "EXECUTE_ROLLOVER");
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
