import 'package:appintern/core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/controllers/goal_controller.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:appintern/ui/widgets/dialogs/goal_sweep_dialog.dart' as import_goal_sweep_dialog;

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
          icon: Icon(Icons.arrow_back_ios, color: const Color(0xFF0B4A3A), size: 20.sp),
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
            icon: Icon(Icons.savings_outlined, color: const Color(0xFFEBC14F), size: 24.sp),
            onPressed: () {
              if (controller.budgetService.unallocatedAmount.value > 0) {
                Get.dialog(
                  import_goal_sweep_dialog.GoalSweepDialog(
                    unallocatedAmount: controller.budgetService.unallocatedAmount.value,
                    onConfirm: () {
                      Get.toNamed(Routes.BUDGET_DISTRIBUTION);
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
        if (controller.isLoading.value && controller.goals.isEmpty) {
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
                  ...controller.goals.map((goal) => _buildGoalCard(goal, formatter)).toList(),

                SizedBox(height: 32.h),

                SizedBox(height: 100.h),
              ],
            ),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.toNamed(Routes.GOAL_CREATE)?.then((_) => controller.fetchGoals()),
        backgroundColor: const Color(0xFF0B4A3A),
        child: const Icon(Icons.add, color: Color(0xFFEBC14F)),
      ),
    );
  }

  Widget _buildGoalCard(GoalModel goal, NumberFormat formatter) {
    final progress = controller.getGoalProgress(goal);
    final savedAmount = controller.getSavedAmount(goal);
    
    // Tìm icon của category
    final goalCategory = controller.budgetService.categories.firstWhereOrNull((c) => c.categoryModel.id == goal.categoryId);
    String iconName = 'icon_expense';
    if (goalCategory != null) {
      iconName = goalCategory.categoryModel.iconName;
    }

    String deadlineText = "Không có thời hạn";
    if (goal.deadline != null) {
      deadlineText = "Dự kiến: ${DateFormat('dd/MM/yyyy').format(goal.deadline!)}";
    }

    return GestureDetector(
      onTap: () {
        Get.toNamed(Routes.GOAL_DETAIL, arguments: goal)?.then((_) => controller.fetchGoals());
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B4A3A).withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B4A3A).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: CustomIconWidget(
                    iconName: iconName,
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 12.w),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        deadlineText,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                // Percentage Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B4A3A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    "${(progress * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B4A3A),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            // Amounts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${formatter.format(savedAmount)} đ",
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0B4A3A),
                  ),
                ),
                Text(
                  "/ ${formatter.format(goal.targetAmount)} đ",
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEBC14F)),
                minHeight: 6.h,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
