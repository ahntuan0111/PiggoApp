import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/controllers/goal_controller.dart';
import 'package:appintern/data/models/goal_model.dart';

import 'package:appintern/ui/widgets/goal_saving_card_item.dart';
import 'package:appintern/ui/widgets/dialogs/goal_sweep_dialog.dart'
    as import_goal_sweep_dialog;
import 'package:appintern/ui/widgets/bottom_sheet/edit_money_distribution.dart';
import 'package:appintern/core/services/network_service.dart';

class GoalScreen extends GetView<GoalController> {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.colorScheme.primary,
            size: 20.sp,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Mục Tiêu",
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading && controller.goals.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.fetchGoals,
          color: theme.colorScheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tổng tiết kiệm
                Center(
                  child: Column(
                    children: [
                      Text(
                        "TỔNG TIẾT KIỆM",
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        CurrencyFormatter.format(controller.totalSaved),
                        style: TextStyle(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),

                // Tiêu đề danh sách
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Mục tiêu của bạn",
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                // Danh sách mục tiêu
                if (controller.goals.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.w),
                      child: Text(
                        "Bạn chưa có mục tiêu nào.",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  )
                else
                  ...controller.goals
                      .map((goal) => _buildGoalCard(goal)),

                SizedBox(height: 32.h),

                SizedBox(height: 100.h),
              ],
            ),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.toNamed(
          Routes.GOAL_CREATE,
        )?.then((_) => controller.fetchGoals()),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Color(0xFFEBC14F)),
      ),
    );
  }

  Widget _buildGoalCard(GoalModel goal) {
    final progress = controller.getGoalProgress(goal);
    final savedAmount = controller.getSavedAmount(goal);

    // Tìm icon của category
    final goalCategory = controller.budgetService.categories.firstWhereOrNull(
      (c) => c.categoryModel.id == goal.categoryId,
    );
    String iconName = 'icon_expense';
    if (goalCategory != null) {
      iconName = goalCategory.categoryModel.iconName;
    }

    String deadlineString = "Không có";
    String timeLeftString = "Vô hạn";
    if (goal.status == 'COMPLETED') {
      timeLeftString = "🎉 Đã hoàn thành";
    } else if (goal.deadline != null) {
      deadlineString = DateFormat('MM/yyyy').format(goal.deadline!);
      final now = DateTime.now();
      final difference = goal.deadline!.difference(now);
      final months = (difference.inDays / 30).floor();
      if (months > 0) {
        timeLeftString = "Còn $months tháng";
      } else if (difference.inDays > 0) {
        timeLeftString = "Còn ${difference.inDays} ngày";
      } else {
        timeLeftString = "Đã đến hạn";
      }
    }

    return Padding(
      key: ValueKey(goal.id),
      padding: EdgeInsets.only(bottom: 16.h),
      child: GoalSavingCardItem(
        title: goal.name,
        deadlineString: deadlineString,
        formattedCurrentAmount: CurrencyFormatter.format(savedAmount),
        formattedTargetAmount: CurrencyFormatter.format(goal.targetAmount),
        progress: progress,
        progressText: "${(progress * 100).toStringAsFixed(1)}%",
        timeLeftString: timeLeftString,
        iconName: iconName,
        isCompleted: goal.status == 'COMPLETED',
        onTap: () async {
          final result = await Get.toNamed(Routes.GOAL_DETAIL, arguments: goal);
          if (result == true) {
            controller.showSuccessMessage(
              'Thành công',
              'Đã xóa mục tiêu tiết kiệm',
            );
            controller.fetchGoals();
          }
        },
        onBreakPiggyBank: goal.status == 'COMPLETED' ? () async {
          final result = await Get.toNamed(Routes.GOAL_DETAIL, arguments: goal);
          if (result == true) {
            controller.fetchGoals();
          }
        } : null,
        onAddFunds: goal.status == 'COMPLETED' ? null : () {
          if (goalCategory == null) return;
          Get.bottomSheet(
            EditMoneyDistributionBottomSheet(
              initialAllocated: goalCategory.allocated,
              unallocatedAmount:
                  controller.budgetService.unallocatedAmount.value,
              categoryGroups: controller.budgetService.activeCategoryGroups,
              currentCategoryId: goalCategory.categoryModel.id,
              isGoal: true,
              onSave:
                  (
                    newBudget, {
                    sourceCategoryId,
                    sourceCategoryNewBudget,
                    note,
                  }) async {
                    if (Get.isBottomSheetOpen == true) {
                      Get.back(); // close bottom sheet immediately to prevent spam
                    }
                    await controller.updateGoalBudget(
                      goalCategory,
                      newBudget,
                      sourceCategoryId: sourceCategoryId,
                      sourceCategoryNewBudget: sourceCategoryNewBudget,
                      note: note,
                    );
                  },
            ),
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
          );
        },
      ),
    );
  }
}
