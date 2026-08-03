import 'package:appintern/core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/controllers/goal_controller.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:appintern/ui/widgets/goal_saving_card_item.dart';
import 'package:appintern/ui/widgets/dialogs/goal_sweep_dialog.dart'
    as import_goal_sweep_dialog;
import 'package:appintern/ui/widgets/bottom_sheet/edit_money_distribution.dart';
import 'package:appintern/core/services/network_service.dart';

class GoalScreen extends GetView<GoalController> {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1), // Màu nền nhẹ của app
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: const Color(0xFF0B4A3A),
            size: 20.sp,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Mục Tiêu",
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0B4A3A),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.savings_outlined,
              color: const Color(0xFFEBC14F),
              size: 24.sp,
            ),
            onPressed: () {
              if (controller.budgetService.unallocatedAmount.value > 0) {
                Get.dialog(
                  import_goal_sweep_dialog.GoalSweepDialog(
                    unallocatedAmount:
                        controller.budgetService.unallocatedAmount.value,
                    onConfirm: () async {
                      final result = await Get.toNamed(Routes.BUDGET_DISTRIBUTION);
                      if (result == true) {
                        final isOffline = Get.find<NetworkService>().isOffline.value;
                        if (isOffline) {
                          controller.showSuccessMessage(
                            "Đã lưu (Ngoại tuyến)",
                            "Dữ liệu sẽ được đồng bộ khi có mạng",
                          );
                        } else {
                          controller.showSuccessMessage(
                            "Thành công",
                            "Đã lưu cấu hình ngân sách",
                          );
                        }
                      }
                    },
                  ),
                );
              } else {
                Get.snackbar("Thông báo", "Bạn không có tiền dư để tiết kiệm.");
              }
            },
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading && controller.goals.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.fetchGoals,
          color: const Color(0xFFD32F2F),
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
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        "${formatter.format(controller.totalSaved.value)} đ",
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B4A3A),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40.h),

                // Tiêu đề danh sách
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Mục tiêu của bạn",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        "Xem tất cả >",
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEBC14F),
                        ),
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
                      .map((goal) => _buildGoalCard(goal, formatter))
                      .toList(),

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
        backgroundColor: const Color(0xFF0B4A3A),
        child: const Icon(Icons.add, color: Color(0xFFEBC14F)),
      ),
    );
  }

  Widget _buildGoalCard(GoalModel goal, NumberFormat formatter) {
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
    if (goal.deadline != null) {
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
      padding: EdgeInsets.only(bottom: 16.h),
      child: GoalSavingCardItem(
        title: goal.name,
        deadlineString: deadlineString,
        formattedCurrentAmount: "${formatter.format(savedAmount)} đ",
        formattedTargetAmount: "${formatter.format(goal.targetAmount)} đ",
        progress: progress,
        progressText: "${(progress * 100).toStringAsFixed(1)}%",
        timeLeftString: timeLeftString,
        iconName: iconName,
        onTap: () async {
          final result = await Get.toNamed(
            Routes.GOAL_DETAIL,
            arguments: goal,
          );
          if (result == true) {
            controller.showSuccessMessage(
              'Thành công',
              'Đã xóa mục tiêu tiết kiệm',
            );
          }
          controller.fetchGoals();
        },
        onAddFunds: () {
          if (goalCategory == null) return;
          Get.bottomSheet(
            EditMoneyDistributionBottomSheet(
              initialAllocated: goalCategory.categoryModel.defaultBudget,
              unallocatedAmount: controller.budgetService.unallocatedAmount.value,
              categoryGroups: controller.budgetService.categoryGroups,
              currentCategoryId: goalCategory.categoryModel.id,
              isGoal: true,
              onSave: (newBudget, {sourceCategoryId, sourceCategoryNewBudget, note}) async {
                await controller.updateGoalBudget(
                  goalCategory,
                  newBudget,
                  sourceCategoryId: sourceCategoryId,
                  sourceCategoryNewBudget: sourceCategoryNewBudget,
                  note: note,
                );
                if (Get.isBottomSheetOpen == true) Get.back(); // close bottom sheet
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
