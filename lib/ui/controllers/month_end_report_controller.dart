import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/data/repositories/rollover_repository.dart';

class MonthEndReportController extends BaseController {
  final RolloverRepository rolloverRepository = Get.find<RolloverRepository>();
  final BudgetService budgetService = Get.find<BudgetService>();

  var currentState = RolloverState.noPending.obs;
  var lastActiveMonthYear = "".obs;

  var oldMonthName = "".obs;
  var newMonthName = "".obs;
  var prevMonthName = "".obs;

  final RxDouble income = 0.0.obs;
  final RxDouble expense = 0.0.obs;
  final RxDouble balance = 0.0.obs;
  final RxDouble carriedOverBalance = 0.0.obs;
  final RxDouble efficiency = 0.0.obs;
  final RxBool isSurplus = true.obs;

  var biggestSavingTitle = "Chưa có".obs;
  var biggestSavingAmount = 0.0.obs;
  var biggestExpenseTitle = "Chưa có".obs;
  var biggestExpenseAmount = 0.0.obs;

  RolloverData? rawRolloverData;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args['state'] != null) {
        currentState.value = args['state'];
      }
      if (args['lastActiveMonthYear'] != null) {
        lastActiveMonthYear.value = args['lastActiveMonthYear'];
        int oldM =
            int.tryParse(lastActiveMonthYear.value.substring(0, 2)) ??
            DateTime.now().month;
        int pM = oldM == 1 ? 12 : oldM - 1;
        prevMonthName.value = pM.toString();
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
    // Đảm bảo budgetService đã tính xong totalWalletBalance mới nhất
    await budgetService.refreshData();

    final result = await ErrorHandler.execute(() async {
      return await rolloverRepository.getRolloverData(
        budgetService.currentUserId.value,
        lastActiveMonthYear.value,
      );
    }, tag: "LOAD_ROLLOVER_DATA");
    hideLoading();

    result.fold((failure) => showErrorMessage("Lỗi", failure.message), (data) {
      rawRolloverData = data;

      if (data.summary != null) {
        income.value = data.summary!.totalIncome;
        expense.value = data.summary!.totalExpense;
      } else {
        income.value = 0.0;
        expense.value = 0.0;
      }

      balance.value = income.value - expense.value;

      carriedOverBalance.value =
          budgetService.totalWalletBalance.value - balance.value;
      if (carriedOverBalance.value < 0) carriedOverBalance.value = 0;

      double totalInflow = income.value;
      if (totalInflow > 0) {
        efficiency.value = (balance.value / totalInflow) * 100;
      } else {
        efficiency.value = 0.0;
      }
      isSurplus.value = balance.value >= 0;

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
    });
  }

  void onNext() {
    if (rawRolloverData != null) {
      Get.toNamed(
        Routes.ROLLOVER_DECISION,
        arguments: {
          'rolloverData': rawRolloverData,
          'lastActiveMonthYear': lastActiveMonthYear.value,
          'currentState': currentState.value,
        },
      );
    }
  }
}
