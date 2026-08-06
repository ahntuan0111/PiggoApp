import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/core/theme/app_colors.dart';

class NumberFormatBottomSheet extends StatelessWidget {
  final String currentFormat;
  final String symbol;
  final String position;
  final Function(String) onSelected;

  const NumberFormatBottomSheet({
    super.key,
    required this.currentFormat,
    required this.symbol,
    required this.position,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        top: 8.h,
        bottom: 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Text(
                  'Cài đặt định dạng số tiền',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _buildOption('comma', '123,457', context),
          SizedBox(height: 12.h),
          _buildOption('dot', '123.457', context),
          SizedBox(height: 12.h),
          _buildOption('space', '123 457', context),
          SizedBox(height: 12.h),
          _buildOption('none', '123457', context),
        ],
      ),
    );
  }

  Widget _buildOption(String formatKey, String numStr, BuildContext context) {
    final isSelected = formatKey == currentFormat;
    
    String displayText = '';
    switch (position) {
      case 'before':
        displayText = '$symbol$numStr';
        break;
      case 'hidden':
        displayText = numStr;
        break;
      case 'after':
      default:
        displayText = '$numStr$symbol';
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: InkWell(
        onTap: () => onSelected(formatKey),
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF9E6) : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? const Color(0xFFFFC107) : AppColors.gray200,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayText,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppColors.text,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              if (isSelected)
                Icon(Icons.check, color: AppColors.text, size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }
}
