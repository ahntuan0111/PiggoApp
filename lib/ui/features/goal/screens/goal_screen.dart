import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/features/goal/controllers/goal_controller.dart';
import 'package:appintern/data/models/goal_model.dart';

import 'package:appintern/ui/features/goal/widgets/goal_saving_card_item.dart';
import 'package:appintern/ui/features/transaction/widgets/goal_sweep_dialog.dart'
    as import_goal_sweep_dialog;
import 'package:appintern/ui/features/budget/widgets/edit_money_distribution.dart';
import 'package:appintern/core/services/network_service.dart';

class GoalScreen extends GetView<GoalController> {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Obx(() {
        if (controller.isLoading && controller.goals.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeGoals = controller.goals.where((g) => g.status != 'COMPLETED').toList();
        final completedGoals = controller.goals.where((g) => g.status == 'COMPLETED').toList();

        return RefreshIndicator(
          onRefresh: controller.fetchGoals,
          color: const Color(0xFF0B4A3A),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Gamified Hero Header
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16.h,
                    bottom: 32.h,
                    left: 24.w,
                    right: 24.w,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B4A3A),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32.r),
                      bottomRight: Radius.circular(32.r),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B4A3A).withValues(alpha: 0.3),
                        blurRadius: 16.r,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Custom AppBar inside Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                            onPressed: () => Get.back(),
                          ),
                          Text(
                            "Mục Tiêu Tiết Kiệm",
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 40.w), // Balance for back button
                        ],
                      ),
                      SizedBox(height: 24.h),
                      
                      // Total XP / Savings
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars, color: const Color(0xFFEBC14F), size: 16.sp),
                            SizedBox(width: 6.w),
                            Text(
                              "TỔNG TIỀN TÍCH LŨY",
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.9),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        CurrencyFormatter.format(controller.totalSaved),
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFEBC14F),
                          shadows: [
                            Shadow(
                              color: const Color(0xFFEBC14F).withValues(alpha: 0.4),
                              blurRadius: 12.r,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      
                      // Stats Row
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16.w,
                        runSpacing: 8.h,
                        children: [
                          _buildStatBadge(
                            icon: Icons.flag,
                            text: "${activeGoals.length} Mục Tiêu Đang Chạy",
                            color: Colors.white,
                          ),
                          _buildStatBadge(
                            icon: Icons.emoji_events,
                            text: "${completedGoals.length} Đã Hoàn Thành",
                            color: const Color(0xFFEBC14F),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Content Area
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (controller.goals.isEmpty) ...[
                      SizedBox(height: 40.h),
                      _buildEmptyState(isDark),
                    ] else ...[
                      if (activeGoals.isNotEmpty) ...[
                        _buildSectionTitle("⏳ Đang Thực Hiện", const Color(0xFF369B56), isDark),
                        SizedBox(height: 16.h),
                        ...activeGoals.map((goal) => _buildGoalCard(goal)),
                        SizedBox(height: 24.h),
                      ],
                      if (completedGoals.isNotEmpty) ...[
                        _buildSectionTitle("🏆 Đã Hoàn Thành", const Color(0xFFEBC14F), isDark),
                        SizedBox(height: 16.h),
                        ...completedGoals.map((goal) => _buildGoalCard(goal)),
                      ],
                    ],
                    SizedBox(height: 100.h), // Space for FAB
                  ]),
                ),
              ),
            ],
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(Routes.GOAL_CREATE)?.then((_) => controller.fetchGoals()),
        backgroundColor: const Color(0xFF0B4A3A),
        icon: const Icon(Icons.add, color: Color(0xFFEBC14F)),
        label: Text(
          "Tạo Mục Tiêu",
          style: TextStyle(
            color: const Color(0xFFEBC14F),
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatBadge({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color, bool isDark) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Container(
            height: 1.h,
            color: color.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFCF5D5),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEBC14F).withValues(alpha: 0.3),
                  blurRadius: 20.r,
                  spreadRadius: 5.r,
                )
              ],
            ),
            child: Text('🎯', style: TextStyle(fontSize: 60.sp)),
          ),
          SizedBox(height: 24.h),
          Text(
            "Chưa có mục tiêu nào!",
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Hãy bắt đầu hành trình tiết kiệm\nbằng cách tạo mục tiêu đầu tiên.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
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
