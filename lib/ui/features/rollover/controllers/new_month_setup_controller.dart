import 'package:appintern/core/enums/rollover_option.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/data/repositories/rollover_repository.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';

import 'package:appintern/core/utils/currency_formatter.dart';

class NewMonthSetupController extends BaseController {
  final RolloverRepository rolloverRepository = Get.find<RolloverRepository>();
  final BudgetService budgetService = Get.find<BudgetService>();

  var expectedIncomeText = "".obs;
  var totalAllocatedAmount = 0.0.obs;
  var clonedCategories = <Map<String, dynamic>>[].obs;

  List<Map<String, dynamic>> decisionCategories = [];
  RolloverData? rawRolloverData;
  String lastActiveMonthYear = "";
  var newMonthName = "".obs;
  List<String> goalCategoryIds = [];

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args['decisionCategories'] != null) {
        decisionCategories = args['decisionCategories'];
      }
      if (args['rawRolloverData'] != null) {
        rawRolloverData = args['rawRolloverData'];
      }
      if (args['goalCategoryIds'] != null) {
        goalCategoryIds = List<String>.from(args['goalCategoryIds']);
      }
      if (args['lastActiveMonthYear'] != null) {
        lastActiveMonthYear = args['lastActiveMonthYear'];

        int newM = DateTime.now().month;
        int newY = DateTime.now().year;

        if (lastActiveMonthYear.length == 7) {
          int oldM = int.tryParse(lastActiveMonthYear.substring(0, 2)) ?? newM;
          int oldY = int.tryParse(lastActiveMonthYear.substring(3)) ?? newY;

          newM = oldM == 12 ? 1 : oldM + 1;
          newY = oldM == 12 ? oldY + 1 : oldY;
        }
        newMonthName.value = "Tháng $newM, $newY";
      }
    }
  }

  @override
  void onReady() {
    super.onReady();
    if (rawRolloverData != null) {
      _setupData(rawRolloverData!);
    }
  }

  void _setupData(RolloverData data) {
    // Filter out goal categories from being displayed as expense budgets
    final expenseCategories = data.categories.where((c) => !goalCategoryIds.contains(c.id)).toList();

    double totalDefaultBudgets = expenseCategories.fold(
      0.0,
      (sum, cat) => sum + cat.defaultBudget,
    );
    totalAllocatedAmount.value = totalDefaultBudgets;

    clonedCategories.assignAll(
      expenseCategories
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
  }

  void onExpectedIncomeChanged(String value) {
    expectedIncomeText.value = value;
  }

  Future<void> onStartHardReset() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      Map<String, double> updatedBudgets = {};
      for (var cat in clonedCategories) {
        updatedBudgets[cat['id']] = (cat['budget'] as num).toDouble();
      }

      Map<String, double> rolloverAmounts = {};

      // === GOAL CARRY OVER (tự động) ===
      if (rawRolloverData != null) {
        for (var b in rawRolloverData!.budgets) {
          if (goalCategoryIds.contains(b.categoryId)) {
            double goalRemaining =
                (b.budgetedAmount + b.rolloverAmount) - b.spentAmount;
            if (goalRemaining > 0) {
              rolloverAmounts[b.categoryId] = goalRemaining;
            }
          }
        }
      }

      for (var cat in decisionCategories) {
        double balance = (cat['balance'] as num).toDouble();
        RolloverOption option = cat['selectedOption'] is RolloverOption
            ? cat['selectedOption']
            : (cat['selectedOption'] as Rx<RolloverOption>).value;

        if (cat['isUnallocatedItem'] == true) {
          if (option == RolloverOption.sweepToSavings) {
            var allocations = cat['targetGoalAllocations'] as Map<String, dynamic>?;
            if (allocations != null) {
              allocations.forEach((goalId, amount) {
                double parsedAmount = (amount as num).toDouble();
                rolloverAmounts[goalId] = (rolloverAmounts[goalId] ?? 0.0) + parsedAmount;
              });
            }
          }
          continue;
        }

        String id = cat['id'];

        if (option == RolloverOption.sweepToSavings) {
          var allocations = cat['targetGoalAllocations'] as Map<String, dynamic>?;
          if (allocations != null) {
            allocations.forEach((goalId, amount) {
              double parsedAmount = (amount as num).toDouble();
              rolloverAmounts[goalId] = (rolloverAmounts[goalId] ?? 0.0) + parsedAmount;
            });
          }
          rolloverAmounts[id] = 0.0;
        } else if (option == RolloverOption.rolloverToCategory) {
          rolloverAmounts[id] = balance;
        } else if (option == RolloverOption.sweepToUnallocated) {
          rolloverAmounts[id] = 0.0;
        } else if (option == RolloverOption.reduceBudget) {
          rolloverAmounts[id] = balance;
        } else {
          rolloverAmounts[id] = 0.0;
        }
      }

      await rolloverRepository.executeRollover(
        budgetService.currentUserId.value,
        updatedBudgets,
        rolloverAmounts,
        goalCategoryIds: goalCategoryIds.toSet(),
      );

      final txRepo = Get.find<TransactionRepository>();
      final now = DateTime.now();
      final firstDayOfMonthForComp = DateTime(now.year, now.month, 1, 8, 0, 0);

      // === TẠO TRANSACTION BÙ THÂM HỤT TỪ DP ===
      double totalDeficitCovered = 0;
      for (var cat in decisionCategories) {
        double balance = (cat['balance'] as num).toDouble();
        RolloverOption option = cat['selectedOption'] is RolloverOption
            ? cat['selectedOption']
            : (cat['selectedOption'] as Rx<RolloverOption>).value;

        if (balance < 0 && option == RolloverOption.sweepToUnallocated) {
          totalDeficitCovered += balance.abs();
        }
      }

      if (totalDeficitCovered > 0) {
        final compensatingTx = TransactionModel(
          id: '',
          categoryId: 'SYSTEM_ROLLOVER',
          amount: totalDeficitCovered,
          type: 'EXPENSE',
          transactionDate: firstDayOfMonthForComp.add(const Duration(seconds: 3)),
          status: 'COMPLETED',
          note: 'Bù thâm hụt tháng trước từ Quỹ Dự Phòng',
        );
        final compensatingDet = TransactionDetailModel(
          id: '',
          transactionId: '',
          note: 'Tự động bù thâm hụt khi chuyển giao tháng',
          receiptFileIds: [],
          rawInputText: '',
          confidenceScore: 1.0,
        );
        await txRepo.createWalletAdjustmentTransaction(
          transaction: compensatingTx,
          transactionDetail: compensatingDet,
        );
      }

      double expectedIncome = CurrencyFormatter.parse(expectedIncomeText.value);

      if (expectedIncome > 0) {
        final firstDayOfMonth = DateTime(now.year, now.month, 1, 8, 0, 0);

        final transaction = TransactionModel(
          id: '',
          categoryId: '',
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

      double totalCarryoverSurplus = 0;
      double totalCarryoverDeficit = 0;

      for (var cat in decisionCategories) {
        double balance = (cat['balance'] as num).toDouble();
        if (balance > 0) {
          totalCarryoverSurplus += balance;
        } else if (balance < 0) {
          totalCarryoverDeficit += balance.abs();
        }
      }

      final firstDayOfMonth = DateTime(now.year, now.month, 1, 8, 0, 0);

      if (totalCarryoverSurplus > 0) {
        final tx = TransactionModel(
          id: '',
          categoryId: 'SYSTEM_ROLLOVER',
          amount: totalCarryoverSurplus,
          type: 'INCOME',
          transactionDate: firstDayOfMonth.add(const Duration(seconds: 1)),
          status: 'COMPLETED',
          note: 'Số dư từ tháng trước chuyển sang',
        );
        final det = TransactionDetailModel(
          id: '',
          transactionId: '',
          note: 'Dọn dẹp hệ thống',
          receiptFileIds: [],
          rawInputText: '',
          confidenceScore: 1.0,
        );
        await txRepo.createWalletAdjustmentTransaction(
          transaction: tx,
          transactionDetail: det,
        );
      }

      if (totalCarryoverDeficit > 0) {
        final tx = TransactionModel(
          id: '',
          categoryId: 'SYSTEM_ROLLOVER',
          amount: totalCarryoverDeficit,
          type: 'EXPENSE',
          transactionDate: firstDayOfMonth.add(const Duration(seconds: 2)),
          status: 'COMPLETED',
          note: 'Thâm hụt từ tháng trước chuyển sang',
        );
        final det = TransactionDetailModel(
          id: '',
          transactionId: '',
          note: 'Dọn dẹp hệ thống',
          receiptFileIds: [],
          rawInputText: '',
          confidenceScore: 1.0,
        );
        await txRepo.createWalletAdjustmentTransaction(
          transaction: tx,
          transactionDetail: det,
        );
      }
    }, tag: "EXECUTE_ROLLOVER");
    hideLoading();

    result.fold((failure) => showErrorMessage("Lỗi", failure.message), (_) {
      budgetService.refreshData();
      Get.offAllNamed(Routes.MAIN);
    });
  }
}
