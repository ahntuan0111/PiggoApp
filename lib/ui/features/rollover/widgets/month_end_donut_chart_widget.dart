import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/core/utils/currency_formatter.dart';

class MonthEndDonutChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> expenseByCategory;
  final double totalExpense;

  const MonthEndDonutChartWidget({
    Key? key,
    required this.expenseByCategory,
    required this.totalExpense,
  }) : super(key: key);

  @override
  State<MonthEndDonutChartWidget> createState() =>
      _MonthEndDonutChartWidgetState();
}

class _MonthEndDonutChartWidgetState extends State<MonthEndDonutChartWidget> {
  int touchedIndex = -1;

  final List<Color> _chartColors = [
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
    const Color(0xFFE91E63), // Pink 500
    const Color(0xFF673AB7), // Deep Purple 500
    const Color(0xFF3F51B5), // Indigo 500
    const Color(0xFF03A9F4), // Light Blue 500
    const Color(0xFF009688), // Teal 500
    const Color(0xFF8BC34A), // Light Green 500
    const Color(0xFFFDD835), // Yellow 600
    const Color(0xFFFF5722), // Deep Orange 500
  ];

  @override
  Widget build(BuildContext context) {
    final hasData = widget.expenseByCategory.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi tiết tiêu dùng',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0B4A3A),
            ),
          ),
          SizedBox(height: 24.h),
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
                        ? List.generate(widget.expenseByCategory.length, (i) {
                            final isTouched = i == touchedIndex;
                            final radius = isTouched ? 22.0.r : 16.0.r;
                            final catData = widget.expenseByCategory[i];
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
                              color: Colors.grey[200]!,
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
                      style: TextStyle(fontSize: 12.sp, color: Colors.black54),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      hasData
                          ? CurrencyFormatter.format(widget.totalExpense)
                          : CurrencyFormatter.format(0),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),
          // Legend List
          if (hasData)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.expenseByCategory.length,
              separatorBuilder: (context, index) => Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Divider(height: 1, color: Colors.grey[100]),
              ),
              itemBuilder: (context, index) {
                final catData = widget.expenseByCategory[index];
                final sliceColor = _chartColors[index % _chartColors.length];
                final amount = (catData['amount'] as num).toDouble();
                final name = catData['categoryName'] as String;

                return Row(
                  children: [
                    Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        color: sliceColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(amount),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Text(
                  'Không có chi tiêu nào trong tháng',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14.sp),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
