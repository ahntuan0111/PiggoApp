import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/rollover_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:appintern/ui/widgets/dialogs/rollover_explanation_dialog.dart';
import 'package:appintern/ui/widgets/dialogs/confirm_dialog_widget.dart';
import 'package:appintern/core/routes/app_routes.dart';

class RolloverDecisionScreen extends GetView<RolloverController> {
  const RolloverDecisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1), // Nền Kem
      appBar: AppBar(
        title: Obx(() => Text(
          "Dọn dẹp sổ sách ${controller.oldMonthName.value}",
          style: TextStyle(color: const Color(0xFF0B4A3A), fontWeight: FontWeight.bold, fontSize: 16.sp),
        )),
        centerTitle: true,
        automaticallyImplyLeading: false, // Ngăn back lại
        backgroundColor: const Color(0xFFF9F7F1),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF0B4A3A)),
            onPressed: () {
              Get.dialog(const RolloverExplanationDialog());
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF0B4A3A)),
            onPressed: () {},
          )
        ],
      ),
      body: Column(
        children: [
          // Hero Action (Lazy Action)
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFC49A45)], // Vàng Gold Gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC49A45).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24.r),
                onTap: () {
                  if (!controller.hasActiveGoals) {
                    Get.dialog(
                      ConfirmDialogWidget(
                        title: "Chưa có Quỹ Dự Phòng",
                        content:
                            "Bạn chưa tạo mục tiêu tiết kiệm nào. Hãy khởi tạo một Mục tiêu tiết kiệm để có thể gom tất cả số dư về làm quỹ dự phòng nhé!",
                        confirmText: "Khởi tạo ngay",
                        cancelText: "Bỏ qua",
                        onConfirm: () {
                          Get.back();
                          Get.toNamed(Routes.GOAL_CREATE);
                        },
                      ),
                    );
                  } else {
                    controller.onMassiveLazyAction();
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 20.w),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bolt_rounded, color: Colors.white, size: 32.sp),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Gom tất cả số dư",
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              "Về Quỹ Dự Phòng chỉ với 1 chạm",
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28.sp),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Summary Metrics
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Obx(() => Row(
              children: [
                Expanded(
                  child: _buildMetricItem("TỔNG DƯ", "+${formatter.format(controller.totalSurplus.value)}đ", const Color(0xFF369B56)),
                ),
                Container(width: 1, height: 40.h, color: Colors.black12),
                Expanded(
                  child: _buildMetricItem("TỔNG THÂM HỤT", "${formatter.format(controller.totalDeficit.value)}đ", Colors.red[600]!),
                ),
              ],
            )),
          ),
          
          SizedBox(height: 24.h),

          // Danh sách chi tiết
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Obx(() => Text(
                "DANH SÁCH CHI TIẾT (${controller.decisionCategories.length})",
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black45,
                  letterSpacing: 1.0,
                ),
              )),
            ),
          ),
          SizedBox(height: 12.h),

          // Danh sách các hũ cần xử lý
          Expanded(
            child: Obx(() => ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              itemCount: controller.decisionCategories.length,
              itemBuilder: (context, index) {
                final cat = controller.decisionCategories[index];
                return Obx(() => _buildExpandableCategoryCard(
                  cat,
                  index,
                ));
              },
            )),
          ),

          // Sticky Bottom Bar
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SafeArea(
              child: Obx(() {
                final pendingCount = controller.pendingCount.value;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "TRẠNG THÁI",
                            style: TextStyle(fontSize: 11.sp, color: Colors.black45, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            "Còn $pendingCount hũ chưa xử lý",
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0B4A3A), // Xanh rêu
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    SizedBox(
                      height: 50.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pendingCount == 0 ? const Color(0xFF369B56) : Colors.grey[300],
                          foregroundColor: pendingCount == 0 ? Colors.white : Colors.black45,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.r),
                          ),
                          elevation: pendingCount == 0 ? 5 : 0,
                        ),
                        onPressed: pendingCount == 0 
                          ? () { controller.onFinishRolloverDecision(); } 
                          : () { controller.onFinishRolloverDecision(); }, // Vẫn gọi hàm nhưng controller sẽ check điều kiện
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Text(
                            "Xác nhận & Cắt sổ",
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: Colors.black45, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildExpandableCategoryCard(Map<String, dynamic> cat, int index) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    final title = cat['title'] as String;
    final iconName = cat['icon'] as String;
    final balance = (cat['balance'] as num).toDouble();
    final isSurplus = cat['isSurplus'] as bool;
    final isExpanded = (cat['isExpanded'] as RxBool).value;
    final selectedOption = (cat['selectedOption'] as Rx<RolloverOption>).value;
    final isGoalAvailable = cat['isGoalAvailable'] as bool;
    final isUnallocatedItem = cat['isUnallocatedItem'] as bool;
    
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: isSurplus ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: CustomIconWidget(iconName: iconName, size: 20.sp),
              ),
              title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.sp, color: Colors.black87)),
              subtitle: Text(
                isSurplus ? "Còn dư +${formatter.format(balance)}đ" : "Thâm hụt ${formatter.format(balance)}đ", 
                style: TextStyle(
                  color: isSurplus ? const Color(0xFF369B56) : Colors.red, 
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: Colors.black45,
              ),
              onTap: () {
                controller.toggleCategoryExpand(index);
              },
            ),
          ),
          
          if (isExpanded) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Divider(color: Colors.grey[200], height: 1),
            ),
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bạn muốn xử lý số dư này như thế nào?",
                    style: TextStyle(fontSize: 13.sp, color: Colors.black54),
                  ),
                  SizedBox(height: 16.h),
                  if (isUnallocatedItem) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildSegmentButton(
                            "Tiết kiệm",
                            selectedOption == RolloverOption.sweepToSavings,
                            isEnabled: isGoalAvailable,
                            onTap: () => controller.selectOption(index, RolloverOption.sweepToSavings),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildSegmentButton(
                            "Giữ nguyên DP",
                            selectedOption == RolloverOption.sweepToUnallocated,
                            isEnabled: true,
                            onTap: () => controller.selectOption(index, RolloverOption.sweepToUnallocated),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildSegmentButton(
                            "Tiết kiệm",
                            selectedOption == RolloverOption.sweepToSavings,
                            isEnabled: isGoalAvailable && isSurplus,
                            onTap: () => controller.selectOption(index, RolloverOption.sweepToSavings),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildSegmentButton(
                            isSurplus ? "Cộng dồn" : "Giảm ĐM",
                            selectedOption == (isSurplus ? RolloverOption.rolloverToCategory : RolloverOption.reduceBudget),
                            isEnabled: true,
                            onTap: () => controller.selectOption(index, isSurplus ? RolloverOption.rolloverToCategory : RolloverOption.reduceBudget),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildSegmentButton(
                            isSurplus ? "Chuyển DP" : "Trừ DP",
                            selectedOption == RolloverOption.sweepToUnallocated,
                            isEnabled: true,
                            onTap: () => controller.selectOption(index, RolloverOption.sweepToUnallocated),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String text, bool isSelected, {required bool isEnabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: isEnabled ? onTap : () {
         Get.snackbar(
           "Thông báo", 
           "Vui lòng tạo Mục tiêu tiết kiệm trước", 
           snackPosition: SnackPosition.BOTTOM,
           margin: EdgeInsets.all(20.w),
         );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isEnabled 
              ? (isSelected ? const Color(0xFFE8F5E9) : Colors.white)
              : Colors.grey[100],
          border: Border.all(
            color: isEnabled 
                ? (isSelected ? const Color(0xFF369B56) : Colors.grey[300]!)
                : Colors.grey[200]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20.r),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isEnabled 
                ? (isSelected ? const Color(0xFF369B56) : Colors.black54)
                : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
