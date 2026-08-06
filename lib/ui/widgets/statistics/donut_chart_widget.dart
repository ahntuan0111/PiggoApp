import 'package:appintern/core/theme/app_colors.dart';
import 'package:appintern/ui/controllers/statistics_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/core/utils/currency_formatter.dart';

class DonutChartWidget extends StatefulWidget {
  const DonutChartWidget({super.key});

  @override
  State<DonutChartWidget> createState() => _DonutChartWidgetState();
}

class _DonutChartWidgetState extends State<DonutChartWidget> {
  int touchedIndex = -1;

  final List<Color> _chartColors = [
    // --- 10 Màu ban đầu của bạn (Tone sáng - 400) ---
    const Color(0xFF42A5F5), // Blue
    const Color(0xFF66BB6A), // Green
    const Color(0xFFFFA726), // Orange
    const Color(0xFFAB47BC), // Purple
    const Color(0xFFEF5350), // Red
    const Color(0xFF26C6DA), // Cyan
    const Color(0xFFD4E157), // Lime
    const Color(0xFFFFCA28), // Amber
    const Color(0xFF8D6E63), // Brown
    const Color(0xFF78909C), // Blue Grey
    // --- 8 Màu bổ sung (Tone rực rỡ - 500/600) ---
    const Color(0xFFE91E63), // Pink 500
    const Color(0xFF673AB7), // Deep Purple 500
    const Color(0xFF3F51B5), // Indigo 500
    const Color(0xFF03A9F4), // Light Blue 500
    const Color(0xFF009688), // Teal 500
    const Color(0xFF8BC34A), // Light Green 500
    const Color(0xFFFDD835), // Yellow 600 (Tránh Yellow 500 vì hơi chói)
    const Color(0xFFFF5722), // Deep Orange 500
    // --- 12 Màu bổ sung (Tone đậm - 700) giúp cắt lớp rõ ràng ---
    const Color(0xFFD32F2F), // Red 700
    const Color(0xFFC2185B), // Pink 700
    const Color(0xFF7B1FA2), // Purple 700
    const Color(0xFF512DA8), // Deep Purple 700
    const Color(0xFF303F9F), // Indigo 700
    const Color(0xFF1976D2), // Blue 700
    const Color(0xFF0097A7), // Cyan 700
    const Color(0xFF00796B), // Teal 700
    const Color(0xFF388E3C), // Green 700
    const Color(0xFFF57C00), // Orange 700
    const Color(0xFF6D4C41), // Brown 600
    const Color(0xFF546E7A), // Blue Grey 600
  ];

  void _showCategoryAnalysis(
    String categoryId,
    String categoryName,
    String iconPath,
  ) {
    Get.find<StatisticsController>().selectCategoryForAnalysis(
      categoryId,
      categoryName,
      iconPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StatisticsController>();

    return Obx(() {
      final data = controller.donutChartData;
      final timeframe = controller.donutChartTimeframe.value;
      final expenseByCategory = List<dynamic>.from(
        data['expenseByCategory'] ?? [],
      );
      final totalExpense = (data['totalExpense'] as num?)?.toDouble() ?? 0;
      final hasData = expenseByCategory.isNotEmpty;

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
                  'Phân bổ chi tiêu',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 32.h),
            SizedBox(
              height: 200.h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          if (!hasData) return;
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: hasData ? 4 : 0,
                      centerSpaceRadius: 60.r,
                      sections: hasData
                          ? List.generate(expenseByCategory.length, (i) {
                              final isTouched = i == touchedIndex;
                              final radius = isTouched ? 20.0.r : 16.0.r;
                              final catData = expenseByCategory[i];
                              final amount = (catData['amount'] as num)
                                  .toDouble();
                              final sliceColor =
                                  _chartColors[i % _chartColors.length];

                              return PieChartSectionData(
                                color: sliceColor,
                                value: amount,
                                title: '',
                                radius: radius,
                              );
                            })
                          : [
                              PieChartSectionData(
                                color: AppColors.gray200,
                                value: 100,
                                title: '',
                                radius: 16.r,
                              ),
                            ],
                    ),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOutCubic,
                  ),
                  // Text in the middle
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tổng chi',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        hasData
                            ? CurrencyFormatter.format(totalExpense)
                            : '0 ₫',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),
            // Category List
            if (!hasData)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Text(
                    'Không có chi tiêu nào trong kỳ',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: List.generate(expenseByCategory.length, (index) {
                  final catData = expenseByCategory[index];
                  final amount = (catData['amount'] as num).toDouble();
                  final percent = totalExpense > 0
                      ? (amount / totalExpense * 100)
                      : 0.0;
                  final categoryId = catData['id'] ?? catData['name'];
                  final categoryName = catData['name'];
                  String iconPath =
                      catData['icon'] ?? 'assets/icons/others.png';
                  if (!iconPath.startsWith('assets/')) {
                    iconPath = 'assets/icons/$iconPath';
                  }
                  final color = _chartColors[index % _chartColors.length];

                  return InkWell(
                    onTap: () => _showCategoryAnalysis(
                      categoryId,
                      categoryName,
                      iconPath,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Image.asset(
                              iconPath,
                              width: 20.w,
                              height: 20.h,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.category,
                                    size: 20.w,
                                    color: color,
                                  ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${percent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          SizedBox(
                            width: 80.w,
                            child: Text(
                              CurrencyFormatter.format(amount),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      );
    });
  }
}
