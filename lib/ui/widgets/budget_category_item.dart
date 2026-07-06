import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/data/models/budget_category.dart';

class BudgetCategoryItem extends StatelessWidget {
  final BudgetCategory category;
  final String formattedAllocated;
  final String formattedSpent;
  final String formattedRemaining;

  const BudgetCategoryItem({
    super.key, 
    required this.category,
    required this.formattedAllocated,
    required this.formattedSpent,
    required this.formattedRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
                  child: Text(category.icon, style: TextStyle(fontSize: 20.sp)),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name, 
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500, color: const Color(0xFF1E1E1E)),
                    ),
                    Text(
                      'Đã phân bổ: $formattedAllocated', 
                      style: TextStyle(fontSize: 12.sp, color: const Color(0xFF616161)),
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
                  Text('Đã tiêu', style: TextStyle(fontSize: 12.sp, color: const Color(0xFF616161))),
                  Text(formattedSpent, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1E1E1E))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Còn lại', style: TextStyle(fontSize: 12.sp, color: const Color(0xFF616161))),
                  Text(formattedRemaining, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1E1E1E))),
                ],
              ),
            ],
          ),
          SizedBox(height: 8.h),
          
          // Thanh tiến trình (Progress Bar)
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: category.progress,
              backgroundColor: const Color(0xFFF5F5F5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF9C03C)), // Màu vàng cam
              minHeight: 6.h,
            ),
          )
        ],
      ),
    );
  }
}
