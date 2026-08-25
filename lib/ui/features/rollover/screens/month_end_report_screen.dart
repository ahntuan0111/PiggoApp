import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/features/rollover/controllers/month_end_report_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:appintern/ui/features/rollover/widgets/month_end_donut_chart_widget.dart';
import 'package:appintern/ui/features/rollover/widgets/month_end_trend_area_chart_widget.dart';

class MonthEndReportScreen extends GetView<MonthEndReportController> {
  const MonthEndReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B4A3A)),
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.only(top: 32.h, left: 24.w, right: 24.w),
                  child: Obx(
                    () => Column(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFC49A45,
                            ).withValues(alpha: 0.15),
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
                                  fontWeight: FontWeight.w300,
                                  fontSize: 12.sp,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              controller.isSurplus.value
                                  ? "Tuyệt vời, tháng qua thật rực rỡ!"
                                  : "Tháng qua hơi căng thẳng nhỉ?",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0B4A3A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24.h),

                // Main Content
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    children: [
                      // Hero Card
                      Obx(
                        () => Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: 32.h,
                            horizontal: 24.w,
                          ),
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
                                CurrencyFormatter.format(
                                  controller
                                      .budgetService
                                      .totalWalletBalance
                                      .value,
                                ),
                                style: TextStyle(
                                  fontSize: 36.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1B4332),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                "Số dư sẵn sàng phân bổ",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                              SizedBox(height: 32.h),

                              // Horizontal Stats Row
                              Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _buildHorizontalStat(
                                      "Tổng thu",
                                      "+${CurrencyFormatter.formatNumberOnly(controller.income.value)}",
                                      const Color(0xFF369B56),
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40.h,
                                    color: Colors.grey[200],
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: _buildHorizontalStat(
                                      "Tổng chi",
                                      "-${CurrencyFormatter.formatNumberOnly(controller.expense.value)}",
                                      const Color(0xFFE53935),
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40.h,
                                    color: Colors.grey[200],
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: _buildHorizontalStat(
                                      "Hiệu suất",
                                      "${controller.isSurplus.value ? '+' : ''}${controller.efficiency.value.toStringAsFixed(1)}%",
                                      controller.isSurplus.value
                                          ? const Color(0xFF369B56)
                                          : Colors.red[600]!,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Donut Chart Section
                      Obx(
                        () => MonthEndDonutChartWidget(
                          expenseByCategory: controller.expenseByCategory
                              .toList(),
                          totalExpense: controller.expense.value,
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Trend Area Chart Section
                      Obx(
                        () => MonthEndTrendAreaChartWidget(
                          trendData: Map<String, dynamic>.from(
                            controller.trendChartData,
                          ),
                        ),
                      ),

                      SizedBox(height: 32.h),

                      // Bottom Button (moved inside scroll view)
                      Padding(
                        padding: EdgeInsets.only(bottom: 24.h),
                        child: SizedBox(
                          width: double.infinity,
                          height: 60.h,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B4A3A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              elevation: 5,
                              shadowColor: const Color(
                                0xFF0B4A3A,
                              ).withValues(alpha: 0.5),
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
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHorizontalStat(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
