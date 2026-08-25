import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/ui/features/goal/controllers/goal_detail_controller.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:appintern/ui/features/transaction/widgets/history_transaction_item.dart';
import 'package:appintern/ui/widgets/dialogs/confirm_dialog_widget.dart';
import 'package:appintern/ui/widgets/emoji_picker_bottom_sheet.dart'
    as import_emoji_picker;
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/ui/features/budget/widgets/edit_money_distribution.dart';
import 'package:appintern/core/routes/app_routes.dart';

class GoalDetailScreen extends GetView<GoalDetailController> {
  const GoalDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          "Chi Tiết Mục Tiêu",
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit,
              color: theme.colorScheme.primary,
              size: 22.sp,
            ),
            onPressed: () => _showUpdateDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red, size: 24.sp),
            onPressed: () => _showDeleteConfirm(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshAll,
        color: const Color(0xFF0B4A3A),
        child: Obx(() {
          final goal = controller.goal.value;
          final progress = controller.currentProgress;
          final saved = controller.savedAmount;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _buildHeroProgress(goal, progress, theme, isDark),
              _buildMilestoneTimeline(progress, theme, isDark),
              _buildActionButtons(progress, saved, theme, isDark),
              _buildStatsCards(goal, saved, theme, isDark),
              SizedBox(height: 24.h),
              _buildTransactionHistory(theme, isDark),
              SizedBox(height: 40.h),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHeroProgress(GoalModel goal, double progress, ThemeData theme, bool isDark) {
    // Tìm icon hiện tại
    final category = controller.budgetService.categories.firstWhereOrNull(
      (c) => c.categoryModel.id == goal.categoryId,
    );
    final iconName = category?.categoryModel.iconName ?? '1.png';

    return Container(
      padding: EdgeInsets.symmetric(vertical: 32.h),
      child: Center(
        child: SizedBox(
          width: 220.w,
          height: 220.w,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Ring
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 16.w,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                ),
              ),
              // Foreground Gamified Ring
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return CircularProgressIndicator(
                    value: value,
                    strokeWidth: 16.w,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? const Color(0xFFEBC14F) : const Color(0xFF369B56),
                    ),
                  );
                },
              ),
              // Center Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(iconName: iconName, size: 40.sp),
                    SizedBox(height: 8.h),
                    Text(
                      "${(progress * 100).toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 36.sp,
                        fontWeight: FontWeight.w900,
                        color: progress >= 1.0 ? const Color(0xFFEBC14F) : (isDark ? Colors.white : const Color(0xFF0B4A3A)),
                      ),
                    ),
                    Text(
                      progress >= 1.0 ? "ĐÃ HOÀN THÀNH" : "Đã hoàn thành",
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (controller.hasDropped)
                      Container(
                        margin: EdgeInsets.only(top: 8.h),
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('💪', style: TextStyle(fontSize: 12.sp)),
                            SizedBox(width: 4.w),
                            Text(
                              'Thử thách mới!',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneTimeline(double progress, ThemeData theme, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tiến độ Mục tiêu",
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMilestoneNode(progress >= 0.25, "25%", "🥉"),
              _buildTimelineConnector(progress >= 0.50),
              _buildMilestoneNode(progress >= 0.50, "50%", "🥈"),
              _buildTimelineConnector(progress >= 0.75),
              _buildMilestoneNode(progress >= 0.75, "75%", "🥇"),
              _buildTimelineConnector(progress >= 1.0),
              _buildMilestoneNode(progress >= 1.0, "100%", "🏆"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneNode(bool isReached, String label, String emoji) {
    return Column(
      children: [
        Container(
          width: 40.r,
          height: 40.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isReached ? const Color(0xFFFCF5D5) : Colors.grey.withValues(alpha: 0.2),
            border: Border.all(
              color: isReached ? const Color(0xFFEBC14F) : Colors.transparent,
              width: 2,
            ),
            boxShadow: isReached ? [
              BoxShadow(
                color: const Color(0xFFEBC14F).withValues(alpha: 0.3),
                blurRadius: 8.r,
              )
            ] : null,
          ),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(
                fontSize: 18.sp,
                color: isReached ? Colors.white : Colors.grey,
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: isReached ? const Color(0xFFEBC14F) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector(bool isReached) {
    return Expanded(
      child: Container(
        height: 4.h,
        margin: EdgeInsets.only(bottom: 24.h), // align with circles
        decoration: BoxDecoration(
          color: isReached ? const Color(0xFFEBC14F) : Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }

  Widget _buildActionButtons(double progress, double saved, ThemeData theme, bool isDark) {
    final goal = controller.goal.value;
    if (progress >= 1.0 && saved > 0) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: ElevatedButton.icon(
          onPressed: () {
            Get.toNamed(
              Routes.TRANSACTION_CREATE,
              arguments: {
                'prefillCategory': goal.categoryId,
                'prefillAmount': saved,
              },
            );
          },
          icon: const Icon(Icons.celebration),
          label: const Text(
            "Chi tiêu ngay",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEBC14F),
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 50.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            elevation: 4,
            shadowColor: const Color(0xFFEBC14F).withValues(alpha: 0.5),
          ),
        ),
      );
    } else if (controller.unallocatedAmount > 0) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: OutlinedButton.icon(
          onPressed: () {
            Get.dialog(
              ConfirmDialogWidget(
                title: "Chuyển tiền nhàn rỗi",
                content:
                    "Bạn có chắc chắn muốn chuyển toàn bộ ${CurrencyFormatter.format(controller.unallocatedAmount)} từ ngân sách nhàn rỗi vào mục tiêu này?",
                confirmText: "Chuyển",
                onConfirm: () {
                  Get.back();
                  controller.addUnallocatedToGoal();
                },
              ),
            );
          },
          icon: const Icon(Icons.bolt, color: Color(0xFF369B56)),
          label: Text(
            "Chuyển ${CurrencyFormatter.format(controller.unallocatedAmount)} vào đây",
            style: const TextStyle(
              color: Color(0xFF369B56),
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF369B56), width: 2),
            minimumSize: Size(double.infinity, 50.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            backgroundColor: const Color(0xFF369B56).withValues(alpha: 0.1),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStatsCards(GoalModel goal, double saved, ThemeData theme, bool isDark) {
    String timeLeftString = "Vô hạn";
    if (goal.status == 'COMPLETED') {
      timeLeftString = "Hoàn thành";
    } else if (goal.deadline != null) {
      final now = DateTime.now();
      final difference = goal.deadline!.difference(now);
      if (difference.inDays > 30) {
        timeLeftString = "${(difference.inDays / 30).floor()} tháng";
      } else if (difference.inDays > 0) {
        timeLeftString = "${difference.inDays} ngày";
      } else {
        timeLeftString = "Đã đến hạn";
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: _buildSingleStatCard(
              "Đã tích lũy",
              CurrencyFormatter.format(saved),
              Icons.savings,
              const Color(0xFF369B56),
              isDark,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildSingleStatCard(
              "Mục tiêu",
              CurrencyFormatter.format(goal.targetAmount),
              Icons.flag,
              const Color(0xFF0B4A3A),
              isDark,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildSingleStatCard(
              "Còn lại",
              timeLeftString,
              Icons.timer,
              const Color(0xFFEBC14F),
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFCF5D5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.sp, color: color),
          SizedBox(height: 8.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 10.sp,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(ThemeData theme, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                Icon(Icons.history, color: const Color(0xFF0B4A3A), size: 24.sp),
                SizedBox(width: 8.w),
                Text(
                  "Lịch sử giao dịch",
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (controller.isLoading)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.transactions.isEmpty)
            Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  "Chưa có nhật ký nào.",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.transactions.length,
              itemBuilder: (context, index) {
                final item = controller.transactions[index];
                // Add timeline connector visual inside HistoryTransactionItem wrapper
                return Stack(
                  children: [
                    // Vertical line for timeline
                    if (index != controller.transactions.length - 1)
                      Positioned(
                        left: 28.w,
                        top: 24.h,
                        bottom: 0,
                        child: Container(
                          width: 2.w,
                          color: const Color(0xFF0B4A3A).withValues(alpha: 0.2),
                        ),
                      ),
                    
                    Padding(
                      padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 8.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline Dot
                          Container(
                            margin: EdgeInsets.only(top: 16.h),
                            width: 12.w,
                            height: 12.w,
                            decoration: BoxDecoration(
                              color: item['type'] == 'EXPENSE' ? Colors.red : const Color(0xFF369B56),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          // Content
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9F7F1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: HistoryTransactionItem(
                                categoryName: item['categoryName'] ?? 'Mục tiêu',
                                note: item['note'] ?? '',
                                walletName: item['walletName'] ?? 'Ngân sách',
                                amount: item['amount'] ?? 0.0,
                                type: item['type'] ?? 'EXPENSE',
                                date: item['date'] ?? DateTime.now(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirm() {
    Get.dialog(
      ConfirmDialogWidget(
        title: "Xóa mục tiêu",
        content:
            "Bạn có chắc chắn muốn xóa mục tiêu này? Danh mục tiết kiệm tương ứng cũng sẽ bị xóa.",
        confirmText: "Xóa",
        onConfirm: () async {
          final success = await controller.deleteGoal();
          if (success) {
            if (Get.isDialogOpen == true) {
              Get.back(); // Close dialog
            }
            Get.back(result: true); // Close screen
          }
        },
      ),
    );
  }

  void _showUpdateDialog(BuildContext context) {
    final goal = controller.goal.value;
    final nameController = TextEditingController(text: goal.name);
    final targetController = TextEditingController(
      text: CurrencyFormatter.format(
        goal.targetAmount,
      ).replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final deadlineObx = Rxn<DateTime>(goal.deadline);

    // Tìm icon hiện tại
    final category = controller.budgetService.categories.firstWhereOrNull(
      (c) => c.categoryModel.id == goal.categoryId,
    );
    final iconObx = (category?.categoryModel.iconName ?? '1.png').obs;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Cập nhật mục tiêu",
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: 24.h),

              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Tên mục tiêu",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyFormatter()],
                decoration: InputDecoration(
                  labelText: "Số tiền mục tiêu",
                  prefixText: "${CurrencyFormatter.symbol} ",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              Row(
                children: [
                  Obx(
                    () =>
                        CustomIconWidget(iconName: iconObx.value, size: 32.sp),
                  ),
                  SizedBox(width: 16.w),
                  TextButton(
                    onPressed: () {
                      Get.bottomSheet(
                        import_emoji_picker.EmojiPickerBottomSheet(
                          selectedIcon: iconObx,
                        ),
                      );
                    },
                    child: const Text("Đổi Icon"),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.grey),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Obx(
                      () => Text(
                        deadlineObx.value == null
                            ? "Không có thời hạn"
                            : DateFormat(
                                'dd/MM/yyyy',
                              ).format(deadlineObx.value!),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: deadlineObx.value ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        deadlineObx.value = picked;
                      }
                    },
                    child: const Text("Chọn ngày"),
                  ),
                ],
              ),

              SizedBox(height: 32.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: controller.isLoading
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final target =
                                double.tryParse(
                                  targetController.text.replaceAll(
                                    RegExp(r'[^0-9]'),
                                    '',
                                  ),
                                ) ??
                                0;
                            if (name.isEmpty || target <= 0) {
                              controller.showErrorMessage(
                                "Lỗi",
                                "Vui lòng nhập tên và số tiền hợp lệ",
                              );
                              return;
                            }
                            final success = await controller.updateGoal(
                              name,
                              target,
                              deadlineObx.value,
                              iconObx.value,
                            );
                            if (success) {
                              if (Get.isBottomSheetOpen == true) Get.back();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: controller.isLoading
                        ? SizedBox(
                            width: 24.h,
                            height: 24.h,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            "Lưu thay đổi",
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}
