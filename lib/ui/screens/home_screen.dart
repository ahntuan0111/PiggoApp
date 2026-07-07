import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/ui/widgets/money_distribution_category_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/home_controller.dart';
import 'package:appintern/ui/widgets/budget_category_item.dart';
import 'package:appintern/ui/widgets/empty_category_suggestion_widget.dart';
import 'package:appintern/ui/widgets/dialogs/category_required_dialog.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1), // Nền kem sáng nhạt giống ảnh
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 220.h,
                  width: double.infinity,
                  color: const Color(0xFF0B4A3A),
                  padding: EdgeInsets.only(top: 50.h, left: 16.w, right: 16.w),
                  child: Column(
                    children: [
                      // Thanh công cụ trên cùng
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.settings, color: Colors.white),
                          Column(
                            children: [
                              Text(
                                'Ngân sách tháng',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Row(
                                  children: [
                                    Obx(
                                      () => Text(
                                        controller.currentMonth.value,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                      size: 16.sp,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () async {
                              await Get.toNamed(Routes.CATEGORY);
                              controller.fetchData();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(top: 130.h, left: 16.w, right: 16.w),
                  child: Obx(() {
                    final isNegative = controller.unallocatedAmount.value < 0;
                    return Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: isNegative
                            ? Colors.red.shade100
                            : const Color(0xFFFCF5D5),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Chưa phân bổ',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: const Color(0xFF616161),
                                    ),
                                  ),
                                  Text(
                                    controller.formatCurrency(
                                      controller.unallocatedAmount.value,
                                    ),
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: isNegative
                                          ? Colors.red.shade700
                                          : const Color(0xFF1E1E1E),
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'Đã phân bổ (Còn lại)',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: const Color(0xFF616161),
                                    ),
                                  ),
                                  Text(
                                    controller.formatCurrency(
                                      controller.allocatedAmount.value,
                                    ),
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF4A4A4A),
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  InkWell(
                                    onTap: () async {
                                      await Get.toNamed(Routes.WALLETCREATE);
                                      controller.fetchData();
                                    },
                                    borderRadius: BorderRadius.circular(8.r),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFC49A45),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add,
                                            color: const Color(0xFFC49A45),
                                            size: 16.r,
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            "Thêm Ngân Sách",
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFFC49A45),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 80.w, height: 80.w),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          SizedBox(
                            width: double.infinity,
                            height: 48.h,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (controller.categories.isEmpty) {
                                  showCategoryRequiredDialog(context);
                                  return;
                                }
                                await Get.toNamed(Routes.BUDGET_DISTRIBUTION);
                                controller.fetchData();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF369B56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'GIAO VIỆC CHO TIỀN',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 24.h)),

          SliverToBoxAdapter(
            child: Obx(() {
              if (controller.isLoading.value) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48.h),
                    child: CircularProgressIndicator(
                      color: const Color(0xFFC49A45),
                    ),
                  ),
                );
              }

              if (controller.categories.isEmpty) {
                return const EmptyCategorySuggestionWidget();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: controller.categoryGroups.map((group) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.typeName,
                              style: TextStyle(
                                fontSize: 18.sp,
                                color: const Color(0xFF1E1E1E),
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Column(
                              children: group.categories.map((cat) {
                                return BudgetCategoryItem(
                                  category: cat,
                                  formattedAllocated: controller.formatCurrency(
                                    cat.allocated,
                                  ),
                                  formattedSpent: controller.formatCurrency(
                                    cat.spent,
                                  ),
                                  formattedRemaining: controller.formatCurrency(
                                    cat.remaining,
                                  ),
                                );
                              }).toList(),
                            ),
                            SizedBox(height: 16.h),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            }),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 80.h)),
        ],
      ),
    );
  }
}
