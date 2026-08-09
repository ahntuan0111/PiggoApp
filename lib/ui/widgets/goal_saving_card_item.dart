import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class GoalSavingCardItem extends StatelessWidget {
  final String title;
  final String deadlineString;
  final String formattedCurrentAmount;
  final String formattedTargetAmount;
  final double progress; // 0.0 to 1.0
  final String progressText; // e.g., "7.5%"
  final String timeLeftString; // e.g., "Còn 5 tháng"
  final String iconName;
  final VoidCallback? onAddFunds;
  final VoidCallback? onBreakPiggyBank;
  final bool isCompleted;
  final VoidCallback? onTap;

  const GoalSavingCardItem({
    super.key,
    required this.title,
    required this.deadlineString,
    required this.formattedCurrentAmount,
    required this.formattedTargetAmount,
    required this.progress,
    required this.progressText,
    required this.timeLeftString,
    required this.iconName,
    this.onAddFunds,
    this.onBreakPiggyBank,
    this.isCompleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Define theme colors based on the design
    const primaryColor = Color(0xFF009688); // Teal
    const bgColor = Color(0xFFF0FDF8); // Very light mint green
    const tagBgColor = Color(0xFFCCF3E9); // Light teal for tag
    const amountColor = Color(0xFF00897B); // Darker teal for amounts
    const borderColor = Color(0xFFE0F2F1); // Light border

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Stack(
          children: [
            // Background watermark icon (bottom right)
            Positioned(
              bottom: -30.r,
              right: -30.r,
              child: Icon(
                Icons.add_circle_outline,
                size: 160.r,
                color: Colors.grey.withValues(alpha: 0.08),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Icon, Title, Deadline, Options
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon with glowing ring effect
                      Container(
                        width: 42.r,
                        height: 42.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4DD0E1), Color(0xFF00ACC1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF00ACC1,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8.r,
                              spreadRadius: 2.r,
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(3.r), // Border thickness
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CustomIconWidget(
                              iconName: iconName,
                              size: 20.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),

                      // Title and Tag
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E1E1E),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: tagBgColor,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                'Hạn: $deadlineString',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Amounts Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hiện có',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: const Color(0xFF757575),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            formattedCurrentAmount,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: amountColor,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Mục tiêu',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: const Color(0xFF757575),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            formattedTargetAmount,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF212121),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),

                  // Progress Info Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tiến độ: $progressText',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        timeLeftString,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: const Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),

                  // Custom Progress Bar
                  Container(
                    height: 8.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF26A69A), // Teal fill
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Break Piggy Bank Button (when Goal is completed)
                  if (isCompleted && onBreakPiggyBank != null)
                    SizedBox(
                      width: double.infinity,
                      height: 38.h,
                      child: ElevatedButton(
                        onPressed: onBreakPiggyBank,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEBC14F),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0xFFEBC14F).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🐷', style: TextStyle(fontSize: 20.sp)),
                            SizedBox(width: 8.w),
                            Text(
                              'Khui ống heo',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  // Add Funds Button (when Goal is not yet completed)
                  else if (!isCompleted && onAddFunds != null)
                    SizedBox(
                      width: double.infinity,
                      height: 38.h,
                      child: ElevatedButton(
                        onPressed: onAddFunds,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            side: const BorderSide(
                              color: Color(0xFF80CBC4),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 22.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'Nạp thêm',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
