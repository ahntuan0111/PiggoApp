import 'package:appintern/core/theme/app_colors.dart';
import 'package:appintern/ui/controllers/statistics_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:get/get.dart';

import 'package:appintern/ui/widgets/bottom_sheet/select_source_bottom_sheet.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class CategoryAnalysisWidget extends GetView<StatisticsController> {
  const CategoryAnalysisWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phân tích danh mục',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 20.h),
          Obx(() {
            if (controller.isLoading) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = controller.categoryAnalysisData;
            final categoryName = controller.selectedAnalysisCategoryName.value;
            final iconPath = controller.selectedAnalysisCategoryIcon.value;

            if (data.isEmpty || categoryName.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text("Không có dữ liệu")),
              );
            }

            final labels = data['labels'] as List<String>? ?? [];
            final values = data['values'] as List<double>? ?? [];
            final average = data['average'] as double? ?? 0;
            final timeframe = controller.categoryAnalysisTimeframe.value;

            String avgLabel = 'Trung bình 3 tháng gần đây';
            if (timeframe == 'last_7_days') avgLabel = 'Trung bình 7 ngày qua';
            if (timeframe == 'this_month') avgLabel = 'Trung bình tháng này';
            if (timeframe == '6_months')
              avgLabel = 'Trung bình 6 tháng gần đây';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: AppColors.gray200,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: CustomIconWidget(
                            iconName: iconPath,
                            size: 24.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        final budgetService = Get.find<BudgetService>();
                        Get.bottomSheet(
                          SelectSourceBottomSheet(
                            unallocatedAmount:
                                budgetService.unallocatedAmount.value,
                            categoryGroups: budgetService.categoryGroups,
                            currentCategoryId:
                                controller.selectedAnalysisCategoryId.value,
                            excludeCategoryIds: const [
                              'unallocated',
                            ], // Don't allow selecting 'Tiền chưa phân bổ'
                            showRemainingAmount: false,
                            onSelected: (sourceId, sourceName, _, icon) {
                              controller.selectCategoryForAnalysis(
                                sourceId,
                                sourceName,
                                icon,
                              );
                            },
                          ),
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.all(8.r),
                        child: Icon(
                          Icons.edit,
                          color: AppColors.textSecondary,
                          size: 20.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10.r,
                          height: 10.r,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD4AF37), // Gold/Yellow
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Chi tiêu',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 32.h,
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      decoration: BoxDecoration(
                        color: AppColors.gray200.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: timeframe,
                          icon: Icon(Icons.arrow_drop_down, size: 20.sp),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'last_7_days',
                              child: Text('7 Ngày'),
                            ),
                            DropdownMenuItem(
                              value: 'this_month',
                              child: Text('Tháng này'),
                            ),
                            DropdownMenuItem(
                              value: '3_months',
                              child: Text('3 Tháng'),
                            ),
                            DropdownMenuItem(
                              value: '6_months',
                              child: Text('6 Tháng'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null)
                              controller.changeCategoryAnalysisTimeframe(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  height: 200.h,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: AppColors.gray200,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval:
                                1, // Bắt buộc set interval=1 để tránh vẽ trùng lặp label khi trục X giãn nở
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < labels.length) {
                                // For daily views, skip labels to avoid overlapping
                                if (labels.length > 7 && index % 2 != 0) {
                                  return const SizedBox();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    labels[index],
                                    style: TextStyle(
                                      color: AppColors.text,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                CurrencyFormatter.format(value),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.sp,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (values.length > 1)
                          ? (values.length - 1).toDouble()
                          : 1,
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (int i = 0; i < values.length; i++)
                              FlSpot(i.toDouble(), values[i]),
                          ],
                          isCurved: false,
                          color: const Color(0xFFD4AF37),
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: const Color(0xFFD4AF37),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 500),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  avgLabel,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10.r,
                          height: 10.r,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD4AF37),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          categoryName,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      CurrencyFormatter.format(average),
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
