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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Gamification Colors based on AppTheme
    final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFCF5D5); // Quest Card Bg
    final borderColor = isCompleted ? const Color(0xFFEBC14F) : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFC49A45));
    final primaryColor = const Color(0xFF0B4A3A); // Quest Primary
    final greenColor = const Color(0xFF369B56); // Quest Green

    // Badge Logic
    String badgeText = "Bắt đầu";
    Color badgeColor = Colors.grey;
    if (isCompleted) {
      badgeText = "🏆 HOÀN THÀNH";
      badgeColor = const Color(0xFFEBC14F);
    } else if (progress >= 0.75) {
      badgeText = "🥇 75%";
      badgeColor = const Color(0xFFEBC14F);
    } else if (progress >= 0.5) {
      badgeText = "🥈 50%";
      badgeColor = const Color(0xFFB0BEC5); // Silver
    } else if (progress >= 0.25) {
      badgeText = "🥉 25%";
      badgeColor = const Color(0xFFCD7F32); // Bronze
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: borderColor.withValues(alpha: isCompleted ? 1.0 : 0.5), width: isCompleted ? 2 : 1),
          boxShadow: isCompleted ? [
            BoxShadow(
              color: const Color(0xFFEBC14F).withValues(alpha: 0.2),
              blurRadius: 12.r,
              spreadRadius: 2.r,
            )
          ] : null,
        ),
        child: Stack(
          children: [
            // Confetti/Star watermark for completed
            if (isCompleted)
              Positioned(
                top: 10.r,
                right: 10.r,
                child: Icon(
                  Icons.star_rounded,
                  size: 60.r,
                  color: const Color(0xFFEBC14F).withValues(alpha: 0.1),
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
                      // Icon with gamification ring
                      Container(
                        width: 48.r,
                        height: 48.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [const Color(0xFFEBC14F), isCompleted ? const Color(0xFFEBC14F) : const Color(0xFF0B4A3A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEBC14F).withValues(alpha: 0.3),
                              blurRadius: 6.r,
                              spreadRadius: 1.r,
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(2.r),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF121212) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CustomIconWidget(
                              iconName: iconName,
                              size: 24.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),

                      // Title and Tag
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : primaryColor,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 12.sp, color: isDark ? Colors.grey[400] : const Color(0xFF616161)),
                                SizedBox(width: 4.w),
                                Text(
                                  deadlineString,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF616161),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Quest Badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: isDark ? badgeColor : badgeColor.withValues(red: badgeColor.r * 0.8, green: badgeColor.g * 0.8, blue: badgeColor.b * 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Amounts Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đã thu thập',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: isDark ? Colors.grey[400] : const Color(0xFF616161),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            formattedCurrentAmount,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              color: isCompleted ? const Color(0xFFEBC14F) : greenColor,
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
                              fontSize: 12.sp,
                              color: isDark ? Colors.grey[400] : const Color(0xFF616161),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            formattedTargetAmount,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey[300] : const Color(0xFF424242),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Custom Progress Bar with Gamification
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tiến độ: $progressText',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? const Color(0xFFEBC14F) : primaryColor,
                            ),
                          ),
                          Text(
                            timeLeftString,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: isDark ? Colors.grey[400] : const Color(0xFF757575),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      
                      // Progress Bar Stack
                      SizedBox(
                        height: 12.h,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            // Background
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                            ),
                            // Fill
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isCompleted 
                                      ? [const Color(0xFFF1C40F), const Color(0xFFF39C12)] 
                                      : [const Color(0xFF369B56), const Color(0xFF0B4A3A)],
                                  ),
                                  borderRadius: BorderRadius.circular(6.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isCompleted ? const Color(0xFFF1C40F) : const Color(0xFF369B56)).withValues(alpha: 0.3),
                                      blurRadius: 4.r,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                ),
                              ),
                            ),
                            // Milestone Markers (25, 50, 75)
                            _buildMilestoneMarker(0.25, progress),
                            _buildMilestoneMarker(0.50, progress),
                            _buildMilestoneMarker(0.75, progress),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Actions
                  if (isCompleted && onBreakPiggyBank != null)
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton(
                        onPressed: onBreakPiggyBank,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEBC14F),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: const Color(0xFFEBC14F).withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🏆', style: TextStyle(fontSize: 18.sp)),
                            SizedBox(width: 8.w),
                            Text(
                              'Sử Dụng Tiết Kiệm',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!isCompleted && onAddFunds != null)
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton(
                        onPressed: onAddFunds,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                          foregroundColor: greenColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            side: BorderSide(
                              color: greenColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline, size: 20.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'Nạp Tiền',
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

  Widget _buildMilestoneMarker(double position, double currentProgress) {
    final isReached = currentProgress >= position;
    return Align(
      alignment: Alignment(position * 2 - 1, 0), // map 0..1 to -1..1
      child: Container(
        width: 4.w,
        height: 12.h,
        decoration: BoxDecoration(
          color: isReached ? Colors.white : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }
}
