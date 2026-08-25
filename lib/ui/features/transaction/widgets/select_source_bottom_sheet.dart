import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/data/models/budget_category_group.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class SelectSourceBottomSheet extends StatelessWidget {
  final double unallocatedAmount;
  final List<BudgetCategoryGroup> categoryGroups;
  final String currentCategoryId;
  final List<String> excludeCategoryIds;
  final bool showRemainingAmount;
  final Function(
    String sourceId,
    String sourceName,
    double availableAmount,
    String iconName,
  )
  onSelected;

  const SelectSourceBottomSheet({
    super.key,
    required this.unallocatedAmount,
    required this.categoryGroups,
    required this.currentCategoryId,
    this.excludeCategoryIds = const [],
    this.showRemainingAmount = true,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * 0.85,
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 12.h,
        bottom: 24.h,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Title
          Text(
            "Chọn danh mục",
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          SizedBox(height: 16.h),

          // Tabs (UI only)
          Container(
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9C03C),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Center(
                      child: Text(
                        "Hiện tại (T${DateTime.now().month})",
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          Expanded(
            child: ListView(
              children: [
                // Unallocated money option
                if (!excludeCategoryIds.contains('unallocated'))
                  GestureDetector(
                    onTap: () {
                      onSelected(
                        'unallocated',
                        'Tiền chưa phân bổ',
                        unallocatedAmount,
                        'icon_wallet.png',
                      );
                      Get.back();
                    },
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CustomIconWidget(
                                iconName: 'icon_wallet.png',
                                size: 24.sp,
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                "Tiền chưa phân bổ",
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1E1E1E),
                                ),
                              ),
                            ],
                          ),
                          if (showRemainingAmount)
                            _buildMoneyText(unallocatedAmount),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 24.h),

                // Category Groups
                ...categoryGroups.map((group) {
                  final validCategories = group.categories
                      .where(
                        (c) =>
                            c.categoryModel.id != currentCategoryId &&
                            !excludeCategoryIds.contains(c.categoryModel.id),
                      )
                      .toList();

                  if (validCategories.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            group.typeName,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                          if (showRemainingAmount)
                            Text(
                              "Còn lại",
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: const Color(0xFF757575),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      ...validCategories.map((category) {
                        double remaining = category.allocated - category.spent;
                        if (remaining < 0) remaining = 0;
                        return GestureDetector(
                          onTap: () {
                            onSelected(
                              category.categoryModel.id,
                              category.name,
                              remaining,
                              category.icon,
                            );
                            Get.back();
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 12.h),
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CustomIconWidget(
                                      iconName: category.icon,
                                      size: 24.sp,
                                    ),
                                    SizedBox(width: 12.w),
                                    Text(
                                      category.name,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1E1E1E),
                                      ),
                                    ),
                                  ],
                                ),
                                if (showRemainingAmount)
                                  _buildMoneyText(remaining),
                              ],
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: 12.h),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyText(double amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
      ],
    );
  }
}
