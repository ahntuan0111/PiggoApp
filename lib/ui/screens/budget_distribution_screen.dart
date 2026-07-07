import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/budget_distribution_controller.dart';
import 'package:appintern/ui/widgets/money_distribution_category_item.dart';

class BudgetDistributionScreen extends GetView<BudgetDistributionController> {
  const BudgetDistributionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F6ED),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(4.r),
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: Colors.white, size: 20.r),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Phân bổ ngân sách',
          style: TextStyle(
            fontSize: 18.sp,
            color: const Color(0xFF1E1E1E),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              controller.saveBudgets();
            },
            child: Text(
              'LƯU',
              style: TextStyle(
                color: const Color(0xFFC49A45),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            SizedBox(height: 16.h),

            // Toggle Button (Chỉ UI)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: const Color(0xFFE0E0E0)),
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
                          'Hiện tại (T7)',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Center(
                        child: Text(
                          'Kế tiếp (T8)',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF616161),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Cards Tiền phân bổ
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Row(
                children: [
                  // Tiền chưa phân bổ
                  Expanded(
                    child: Obx(() {
                      final isNegative = controller.unallocatedAmount.value < 0;
                      return Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: isNegative
                              ? Colors.red.shade400
                              : const Color(
                                  0xFF0F4C3A,
                                ), // Đỏ hồng báo động hoặc Xanh thẫm
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tiền chưa phân bổ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                  ),
                                ),
                                Icon(
                                  Icons.info,
                                  color: Colors.white,
                                  size: 12.sp,
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              controller.formatCurrency(
                                controller.unallocatedAmount.value,
                              ),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  SizedBox(width: 12.w),

                  // Tiền đã phân bổ
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9C03C), // Vàng
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tiền đã phân bổ',
                                style: TextStyle(
                                  color: const Color(0xFF1E1E1E),
                                  fontSize: 10.sp,
                                ),
                              ),
                              Icon(
                                Icons.info,
                                color: const Color(0xFF1E1E1E),
                                size: 12.sp,
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            controller.formatCurrency(
                              controller.allocatedAmount.value,
                            ),
                            style: TextStyle(
                              color: const Color(0xFF1E1E1E),
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

            SizedBox(height: 24.h),

            // Danh sách Category
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                itemCount: controller.categoryGroups.length,
                itemBuilder: (context, index) {
                  final group = controller.categoryGroups[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            group.typeName,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                          // Tính tổng đã phân bổ của nhóm này
                          Obx(
                            () => Text(
                              controller.formatCurrency(
                                group.totalAllocated.value,
                              ),
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: const Color(0xFF616161),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Các hạng mục
                      ...group.categories.map((cat) {
                        return MoneyDistributionCategoryItem(
                          category: cat,
                          formattedAllocated: controller.formatCurrency(
                            cat.defaultBudget,
                          ),
                          controller: controller.textControllers[cat.id]!,
                        );
                      }).toList(),

                      SizedBox(height: 16.h),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}
