import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/month_end_report_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class MonthEndReportScreen extends GetView<MonthEndReportController> {
  const MonthEndReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1), // Màu Kem sáng từ home_screen
      body: SafeArea(
        child: Column(
          children: [
            // Cố định Top phần Text
            Padding(
              padding: EdgeInsets.only(top: 40.h, left: 24.w, right: 24.w),
              child: Obx(
                () => Column(
                  children: [
                    // AI Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFC49A45,
                        ).withValues(alpha: 0.15), // Vàng Gold nhạt
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: const Color(0xFFC49A45),
                            size: 16.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            "AI INSIGHT",
                            style: TextStyle(
                              color: const Color(0xFFC49A45),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.sp,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      controller.isSurplus.value
                          ? "Tuyệt vời, tháng qua\nthật rực rỡ!"
                          : "Tháng qua hơi\ncăng thẳng nhỉ?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28.sp,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B4A3A), // Xanh rêu đậm
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      controller.isSurplus.value
                          ? "Bạn đã quản lý chi tiêu cực kỳ hiệu quả\nvà có một khoản dư ấn tượng."
                          : "Bạn đã chi tiêu vượt mức dự kiến,\nnhưng đừng lo, chúng ta sẽ cân bằng lại.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 40.h),

            // Nội dung chính (Scrollable nếu màn nhỏ)
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    // Main Glassmorphism Card
                    Obx(
                      () => Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "TỔNG TIỀN HIỆN CÓ",
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black38,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              "${formatter.format(controller.budgetService.totalWalletBalance.value)}đ",
                              style: TextStyle(
                                fontSize: 36.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1B4332), // Xanh đậm sang trọng
                              ),
                            ),
                            SizedBox(height: 32.h),

                            // Chart & Stats
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Simple Ring Chart Placeholder
                                SizedBox(
                                  width: 60.r,
                                  height: 60.r,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CircularProgressIndicator(
                                        value: 1.0,
                                        strokeWidth: 8.r,
                                        color: const Color(0xFF0B4A3A), // Xanh rêu (Chi)
                                      ),
                                      CircularProgressIndicator(
                                        value: 0.7, // 70% income remaining? Just dummy
                                        strokeWidth: 8.r,
                                        color: const Color(0xFF369B56), // Xanh lá (Thu)
                                      ),
                                      Center(
                                        child: Icon(
                                          Icons.analytics_outlined,
                                          color: Colors.black26,
                                          size: 24.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 32.w),
                                // Stats
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStatRow(
                                      Icons.circle,
                                      const Color(0xFF1B4332),
                                      "Dư từ tháng ${controller.prevMonthName.value}",
                                      "+${formatter.format(controller.carriedOverBalance.value)}",
                                    ),
                                    SizedBox(height: 12.h),
                                    _buildStatRow(
                                      Icons.circle,
                                      const Color(0xFF369B56),
                                      "Tổng thu",
                                      "+${formatter.format(controller.income.value)}",
                                    ),
                                    SizedBox(height: 12.h),
                                    _buildStatRow(
                                      Icons.circle,
                                      const Color(0xFFE53935),
                                      "Tổng chi",
                                      "-${formatter.format(controller.expense.value)}",
                                    ),
                                    SizedBox(height: 16.h),
                                    Row(
                                      children: [
                                        Text(
                                          "Hiệu suất",
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                        SizedBox(width: 16.w),
                                        Text(
                                          "${controller.isSurplus.value ? '+' : ''}${controller.efficiency.value.toStringAsFixed(1)}%",
                                          style: TextStyle(
                                            color: controller.isSurplus.value ? const Color(0xFF369B56) : Colors.red[600],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Mini Cards
                    Obx(
                      () => Row(
                        children: [
                          Expanded(
                            child: _buildMiniCard(
                              icon: Icons.trending_up,
                              iconColor: const Color(0xFF369B56),
                              title: controller.biggestSavingTitle.value,
                              value:
                                  "${formatter.format(controller.biggestSavingAmount.value)}đ",
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: _buildMiniCard(
                              icon: Icons.local_dining,
                              iconColor: const Color(0xFFC49A45),
                              title: "Chi lớn nhất",
                              value: controller.biggestExpenseTitle.value,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Button
            Padding(
              padding: EdgeInsets.all(24.w),
              child: SizedBox(
                width: double.infinity,
                height: 60.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B4A3A), // Xanh rêu
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF0B4A3A).withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    controller.onNext();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Bắt đầu dọn dẹp số dư",
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 10.sp),
        SizedBox(width: 8.w),
        SizedBox(
          width: 60.w,
          child: Text(
            label,
            style: TextStyle(color: Colors.black54, fontSize: 13.sp),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24.sp),
          SizedBox(height: 12.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
