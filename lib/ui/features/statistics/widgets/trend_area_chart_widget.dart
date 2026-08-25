import 'package:appintern/core/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/features/statistics/controllers/statistics_controller.dart';

class TrendAreaChartWidget extends GetView<StatisticsController> {
  const TrendAreaChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final trendData = controller.trendChartData;
      final timeframe = controller.trendChartTimeframe.value;

      final rawLabels = List<String>.from(trendData['labels'] ?? []);
      final datasets = List<dynamic>.from(trendData['datasets'] ?? []);

      // Placeholder if no data
      final hasData = rawLabels.isNotEmpty && datasets.isNotEmpty;
      final labels = hasData
          ? rawLabels
          : ['01', '05', '10', '15', '20', '25', '30'];

      final expenseDataset = datasets.firstWhere(
        (element) =>
            (element['name'] as String).toLowerCase().contains('chi') ||
            (element['name'] as String).toLowerCase().contains('expense'),
        orElse: () => null,
      );

      final values = hasData && expenseDataset != null
          ? List<num>.from(
              expenseDataset['values'],
            ).map((e) => e.toDouble()).toList()
          : List<double>.filled(labels.length, 0);

      double maxY = 0;
      for (var val in values) {
        if (val > maxY) maxY = val;
      }
      maxY = maxY * 1.2;
      if (maxY == 0) maxY = 100000; // Default max Y if no data or all zero

      final color = const Color(0xFFE53935); // Strong red for expense trend

      return Container(
        padding: EdgeInsets.all(20.r),
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
                  'Xu hướng chi tiêu',
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
                        if (val != null) controller.fetchTrendChartData(val);
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
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => AppColors.textPrimary,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          return LineTooltipItem(
                            CurrencyFormatter.format(touchedSpot.y),
                            TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? (maxY / 4) : 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.gray200,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: (labels.length / 5).ceilToDouble().clamp(
                          1.0,
                          double.infinity,
                        ),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= labels.length) {
                            return const SizedBox.shrink();
                          }

                          // Parse label
                          String label = labels[index];
                          if (label.contains('-')) {
                            try {
                              final parts = label.split('-');
                              if (parts.length == 3) {
                                // yyyy-mm-dd
                                label = '${parts[2]}/${parts[1]}';
                              }
                            } catch (_) {}
                          }

                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.sp,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: maxY > 0 ? (maxY / 4) : 1,
                        reservedSize: 42,
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
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (labels.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(values.length, (index) {
                        return FlSpot(index.toDouble(), values[index]);
                      }),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: color,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.5),
                            color.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
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
}
