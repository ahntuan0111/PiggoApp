import 'package:appintern/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/core/utils/currency_formatter.dart';

class BurnRateProgressWidget extends StatelessWidget {
  final Map<String, dynamic> burnRateData;

  const BurnRateProgressWidget({super.key, required this.burnRateData});

  @override
  Widget build(BuildContext context) {
    final totalBudget = (burnRateData['totalBudget'] as num?)?.toDouble() ?? 0;
    final totalExpense =
        (burnRateData['totalExpense'] as num?)?.toDouble() ?? 0;
    final percentage = (burnRateData['percentage'] as num?)?.toDouble() ?? 0;

    // Determine color based on burn rate
    Color progressColor = AppColors.successColor;
    if (percentage > 90) {
      progressColor = AppColors.errorColor;
    } else if (percentage > 70) {
      progressColor = AppColors.warningColor;
    }

    // Calculate remaining
    final remaining = (totalBudget - totalExpense).clamp(0, totalBudget);

    String formatShort(double val) {
      if (val >= 1000000) {
        return '${(val / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
      } else if (val >= 1000) {
        return '${(val / 1000).toStringAsFixed(0)}K';
      }
      return val.toStringAsFixed(0);
    }

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
          Text(
            'Ngân sách tháng này',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            CurrencyFormatter.format(totalBudget),
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(height: 24.h),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: totalBudget > 0
                  ? (totalExpense / totalBudget).clamp(0.0, 1.0)
                  : 0,
            ),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 16.h,
                  backgroundColor: AppColors.gray200,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              );
            },
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã tiêu: ${formatShort(totalExpense.toDouble())}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Còn lại: ${formatShort(remaining.toDouble())}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
