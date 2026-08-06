import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class BudgetCategoryItem extends StatelessWidget {
  final BudgetCategory category;
  final String formattedAllocated;
  final String formattedSpent;
  final String formattedRemaining;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const BudgetCategoryItem({
    super.key,
    required this.category,
    required this.formattedAllocated,
    required this.formattedSpent,
    required this.formattedRemaining,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    bool isOverspent = category.remaining < 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: isOverspent ? const Color(0xFFE53935) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isOverspent
                    ? BorderRadius.vertical(
                        top: Radius.circular(16.r),
                        bottom: Radius.circular(12.r),
                      )
                    : BorderRadius.circular(16.r),
              ),
              child: Column(
                children: [
                  // Dòng 1: Icon, Tên, Số tiền phân bổ
                  Row(
                    children: [
                      Container(
                        width: 40.r,
                        height: 40.r,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFCF5D5), // Vàng nhạt giống thiết kế
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: CustomIconWidget(
                            iconName: category.icon,
                            size: 20.sp,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1E1E1E),
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: 'Đã phân bổ: ',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: const Color(0xFF616161),
                                ),
                                children: [
                                  TextSpan(
                                    text: formattedAllocated,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: isOverspent
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFF616161),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.more_horiz, color: Color(0xFF616161)),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Dòng 2: Đã tiêu và Còn lại
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đã tiêu',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF616161),
                            ),
                          ),
                          Text(
                            formattedSpent,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: isOverspent
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF1E1E1E),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Còn lại',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF616161),
                            ),
                          ),
                          Text(
                            formattedRemaining,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: isOverspent
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF1E1E1E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // Thanh tiến trình (Progress Bar)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: isOverspent ? 1.0 : category.progress,
                      backgroundColor: const Color(0xFFF5F5F5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverspent
                            ? const Color(0xFFE53935)
                            : const Color(0xFFF9C03C),
                      ),
                      minHeight: 6.h,
                    ),
                  ),
                ],
              ),
            ),
            if (isOverspent)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Bạn đã chi tiêu vượt kế hoạch",
                      style: TextStyle(color: Colors.white, fontSize: 12.sp),
                    ),
                    GestureDetector(
                      onTap: onEdit,
                      child: Text(
                        "Chỉnh sửa",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
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
