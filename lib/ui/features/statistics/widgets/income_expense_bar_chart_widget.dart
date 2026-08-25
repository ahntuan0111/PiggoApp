import 'package:appintern/core/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/features/statistics/controllers/statistics_controller.dart';

class IncomeExpenseBarChartWidget extends GetView<StatisticsController> {
  const IncomeExpenseBarChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final trendData = controller.barChartData;
      final timeframe = controller.barChartTimeframe.value;

      if (trendData.isEmpty) {
        return const SizedBox();
      }

      // Process data from 'labels' and 'datasets'
      final rawLabels = List<String>.from(trendData['labels'] ?? []);
      final datasets = List<dynamic>.from(trendData['datasets'] ?? []);

      final hasData = rawLabels.isNotEmpty && datasets.isNotEmpty;

      // Map data to x,y points
      List<BarChartGroupData> barGroups = [];
      List<String> xLabels = [];
      double maxY = 0;

      BarChartGroupData buildBarGroup(int x, double income, double expense) {
        return BarChartGroupData(
          x: x,
          barRods: [
            BarChartRodData(
              toY: income,
              color: AppColors.successColor,
              width: 12.w,
              borderRadius: BorderRadius.circular(4.r),
            ),
            BarChartRodData(
              toY: expense,
              color: const Color(0xFFE53935), // Strong red for expense
              width: 12.w,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ],
        );
      }

      if (!hasData) {
        xLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
        for (int i = 0; i < xLabels.length; i++) {
          barGroups.add(buildBarGroup(i, 0, 0));
        }
      } else {
        final expenseDataset = datasets.firstWhere(
          (e) =>
              (e['name'] as String).toLowerCase().contains('chi') ||
              (e['name'] as String).toLowerCase().contains('expense'),
          orElse: () => null,
        );
        final incomeDataset = datasets.firstWhere(
          (e) =>
              (e['name'] as String).toLowerCase().contains('thu') ||
              (e['name'] as String).toLowerCase().contains('income'),
          orElse: () => null,
        );

        final expenses = expenseDataset != null
            ? List<num>.from(
                expenseDataset['values'],
              ).map((e) => e.toDouble()).toList()
            : List<double>.filled(rawLabels.length, 0);
        final incomes = incomeDataset != null
            ? List<num>.from(
                incomeDataset['values'],
              ).map((e) => e.toDouble()).toList()
            : List<double>.filled(rawLabels.length, 0);

        if (timeframe == 'this_month') {
          // Group by Week (Tuần 1: Days 1-7, Tuần 2: Days 8-14, Tuần 3: Days 15-21, Tuần 4: Days 22+)
          List<double> weeklyIncomes = [0, 0, 0, 0];
          List<double> weeklyExpenses = [0, 0, 0, 0];
          xLabels = ['Tuần 1', 'Tuần 2', 'Tuần 3', 'Tuần 4'];

          for (int i = 0; i < rawLabels.length; i++) {
            int weekIndex = i ~/ 7;
            if (weekIndex > 3) weekIndex = 3;

            if (i < incomes.length) weeklyIncomes[weekIndex] += incomes[i];
            if (i < expenses.length) weeklyExpenses[weekIndex] += expenses[i];
          }

          for (int i = 0; i < 4; i++) {
            double income = weeklyIncomes[i];
            double expense = weeklyExpenses[i];
            if (income > maxY) maxY = income;
            if (expense > maxY) maxY = expense;
            barGroups.add(buildBarGroup(i, income, expense));
          }
        } else {
          // last_7_days, 3_months, 6_months
          for (int i = 0; i < rawLabels.length; i++) {
            double income = i < incomes.length ? incomes[i] : 0;
            double expense = i < expenses.length ? expenses[i] : 0;

            if (income > maxY) maxY = income;
            if (expense > maxY) maxY = expense;

            String label = rawLabels[i];
            if (timeframe == 'last_7_days' && label.contains('/')) {
              label = label.split('/').take(2).join('/'); // Keep only DD/MM
            }
            xLabels.add(label);
            barGroups.add(buildBarGroup(i, income, expense));
          }
        }
      }

      // Add some padding to maxY for visual headroom
      maxY = maxY + (maxY * 0.15);
      if (maxY == 0) maxY = 100000;

      return Container(
        padding: EdgeInsets.all(16.r),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thu & Chi',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                // Timeframe Dropdown
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
                        if (val != null) controller.fetchBarChartData(val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildLegendDot(AppColors.successColor, 'Thu nhập'),
                SizedBox(width: 8.w),
                _buildLegendDot(const Color(0xFFE53935), 'Chi tiêu'),
              ],
            ),
            SizedBox(height: 24.h),
            SizedBox(
              height: 200.h,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => AppColors.textPrimary,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          CurrencyFormatter.format(rod.toY),
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < xLabels.length) {
                            // To avoid overlapping, only show subset if there are many labels
                            if (xLabels.length > 7 && index % 2 != 0)
                              return const SizedBox();
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                xLabels[index],
                                style: TextStyle(
                                  color: AppColors.textSecondary,
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
                        reservedSize: 42,
                        interval: maxY > 0 ? (maxY / 4) : 1,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            CurrencyFormatter.formatCompact(value),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.sp,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? (maxY / 4) : 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: AppColors.gray200, strokeWidth: 1);
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOutCubic,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8.r,
          height: 8.r,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
