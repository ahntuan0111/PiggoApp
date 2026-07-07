import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class MoneyDistributionCategoryItem extends StatelessWidget {
  final CategoryModel category;
  final String formattedAllocated;
  final TextEditingController controller;

  const MoneyDistributionCategoryItem({
    super.key,
    required this.category,
    required this.formattedAllocated,
    required this.controller,
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
                  child: CustomIconWidget(iconName: category.iconName, size: 20.sp),
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
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: const Color(0xFF1E1E1E),
                size: 24.sp,
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Dòng 2: Đã tiêu và Còn lại
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Đã phân bổ',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF616161),
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(
                width: 140.w,
                height: 40.h,
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyFormatter(),
                  ],
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
                    suffixText: 'đ', // Xóa khoảng trắng thừa
                    suffixStyle: TextStyle(
                      color: Colors.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: const BorderSide(
                        color: Color(0xFFF9C03C),
                        width: 1.5,
                      ), // Nhấn mạnh viền khi focus
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
