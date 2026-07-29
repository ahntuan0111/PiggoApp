import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:flutter/material.dart';
import 'package:appintern/ui/widgets/dialogs/rollover_explanation_dialog.dart';
import 'package:appintern/data/repositories/rollover_repository.dart';

enum RolloverOption {
  sweepToSavings, // Tiết kiệm
  rolloverToCategory, // Cộng dồn
  reduceBudget, // Giảm ĐM
  sweepToUnallocated, // Chuyển DP / Trừ DP
}

class RolloverDecisionController extends BaseController {
  final BudgetService budgetService = Get.find<BudgetService>();

  var totalSurplus = 0.0.obs;
  var totalDeficit = 0.0.obs;
  var pendingCount = 0.obs;
  var decisionCategories = <Map<String, dynamic>>[].obs;

  RolloverData? rawRolloverData;
  var lastActiveMonthYear = "".obs;
  var oldMonthName = "".obs;
  var currentState = RolloverState.noPending.obs;

  dynamic get activeGoal {
    if (budgetService.goals.isEmpty) return null;

    int newM = DateTime.now().month;
    int newY = DateTime.now().year;

    if (lastActiveMonthYear.value.length == 7) {
      int oldM =
          int.tryParse(lastActiveMonthYear.value.substring(0, 2)) ?? newM;
      int oldY = int.tryParse(lastActiveMonthYear.value.substring(3)) ?? newY;

      newM = oldM == 12 ? 1 : oldM + 1;
      newY = oldM == 12 ? oldY + 1 : oldY;
    }

    final startOfNewMonth = DateTime(newY, newM, 1);

    return budgetService.goals.firstWhereOrNull((goal) {
      if (goal.deadline == null) return true;
      return goal.deadline!.isAfter(
        startOfNewMonth.subtract(const Duration(days: 1)),
      );
    });
  }

  bool get hasActiveGoals => activeGoal != null;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args['rolloverData'] != null) {
        rawRolloverData = args['rolloverData'];
      }
      if (args['lastActiveMonthYear'] != null) {
        lastActiveMonthYear.value = args['lastActiveMonthYear'];

        if (lastActiveMonthYear.value.length == 7) {
          int oldM =
              int.tryParse(lastActiveMonthYear.value.substring(0, 2)) ??
              DateTime.now().month;
          int oldY =
              int.tryParse(lastActiveMonthYear.value.substring(3)) ??
              DateTime.now().year;
          oldMonthName.value = "Tháng $oldM, $oldY";
        }
      }
      if (args['currentState'] != null) {
        currentState.value = args['currentState'];
      }
    }
  }

  @override
  void onReady() {
    super.onReady();
    if (rawRolloverData != null) {
      _processData(rawRolloverData!);
    }

    // Hiển thị Dialog giải thích thuật ngữ sau khi chuyển màn hình
    Future.delayed(const Duration(milliseconds: 300), () {
      Get.dialog(const RolloverExplanationDialog());
    });
  }

  void _processData(RolloverData data) {
    double tSurplus = 0;
    double tDeficit = 0;
    List<Map<String, dynamic>> cats = [];

    bool hasGoals = hasActiveGoals;

    for (var b in data.budgets) {
      final cat = data.categories.firstWhereOrNull((c) => c.id == b.categoryId);
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
            tDeficit += remaining;
          }
        }
      }
    }

    double actualUnallocated =
        budgetService.totalWalletBalance.value - (tSurplus + tDeficit);
    if (actualUnallocated > 0) {
      cats.insert(0, {
        'id': 'unallocated_pool',
        'title': 'Quỹ chưa phân bổ',
        'icon': 'icon_wallet.png',
        'balance': actualUnallocated,
        'isSurplus': true,
        'isExpanded': false.obs,
        'selectedOption': RolloverOption.sweepToUnallocated.obs,
        'isProcessed': false.obs,
        'isGoalAvailable': hasGoals,
        'isUnallocatedItem': true,
      });
      tSurplus += actualUnallocated;
    }

    totalSurplus.value = tSurplus;
    totalDeficit.value = tDeficit;
    decisionCategories.assignAll(cats);
    pendingCount.value = cats.length;
  }

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
    (cat['isProcessed'] as RxBool).value = true;
    _updatePendingCount();
  }

  void onMassiveLazyAction() {
    for (var cat in decisionCategories) {
      (cat['selectedOption'] as Rx<RolloverOption>).value =
          RolloverOption.sweepToUnallocated;
      (cat['isProcessed'] as RxBool).value = true;
      (cat['isExpanded'] as RxBool).value = false;
    }
    _updatePendingCount();
  }

  void onFinishRolloverDecision() {
    if (pendingCount.value > 0) return;
    Get.toNamed(
      Routes.NEW_MONTH_SETUP,
      arguments: {
        'decisionCategories': decisionCategories,
        'rawRolloverData': rawRolloverData,
        'lastActiveMonthYear': lastActiveMonthYear.value,
        'currentState': currentState.value,
      },
    );
  }
}
