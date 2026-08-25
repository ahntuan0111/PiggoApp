import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/core/theme/app_colors.dart';

class SymbolPositionBottomSheet extends StatelessWidget {
  final String currentPosition;
  final String format;
  final String symbol;
  final Function(String) onSelected;

  const SymbolPositionBottomSheet({
    super.key,
    required this.currentPosition,
    required this.format,
    required this.symbol,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(top: 8.h, bottom: 20.h),
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
                  'Vị trí ký hiệu tiền tệ',
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
          _buildOption('before', 'Trước số tiền', context),
          SizedBox(height: 12.h),
          _buildOption('after', 'Sau số tiền', context),
          SizedBox(height: 12.h),
          _buildOption('hidden', 'Không hiển thị', context),
        ],
      ),
    );
  }

  Widget _buildOption(String positionKey, String label, BuildContext context) {
    final isSelected = positionKey == currentPosition;

    String numStr = '123457';
    switch (format) {
      case 'comma':
        numStr = '123,457';
        break;
      case 'dot':
        numStr = '123.457';
        break;
      case 'space':
        numStr = '123 457';
        break;
      case 'none':
        numStr = '123457';
        break;
    }

    String exampleText = '';
    switch (positionKey) {
      case 'before':
        exampleText = '$symbol$numStr';
        break;
      case 'hidden':
        exampleText = numStr;
        break;
      case 'after':
      default:
        exampleText = '$numStr$symbol';
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: InkWell(
        onTap: () => onSelected(positionKey),
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
                '$label $exampleText',
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
