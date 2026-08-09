import 'package:appintern/core/constants/app_assets.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/home_controller.dart';
import 'package:appintern/ui/widgets/budget_category_item.dart';
import 'package:appintern/ui/widgets/empty_category_suggestion_widget.dart';
import 'package:appintern/ui/widgets/dialogs/category_required_dialog.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/ui/widgets/persistent_offline_banner.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1), // Nền kem sáng nhạt giống ảnh
      body: Column(
        children: [
          const PersistentOfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.fetchData,
              child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 220.h,
                    width: double.infinity,
                    color: const Color(0xFF0B4A3A),
                    padding: EdgeInsets.only(
                      top: 50.h,
                      left: 16.w,
                      right: 16.w,
                    ),
                    child: Column(
                      children: [
                        // Thanh công cụ trên cùng
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              onPressed: () async {
                                await Get.toNamed(Routes.CATEGORY);
                                controller.fetchData();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Obx(
                                        () => Text(
                                          controller.currentMonth,
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
                            Obx(() {
                              final offlineSyncService =
                                  Get.find<OfflineSyncService>();
                              final queueCount =
                                  offlineSyncService.aiQueueCount.value;

                              return IconButton(
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(
                                      Icons.notifications,
                                      color: Colors.white,
                                    ),
                                    if (queueCount > 0)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: EdgeInsets.all(4.w),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            queueCount.toString(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                onPressed: () {
                                  Get.toNamed(Routes.OFFLINE_QUEUE);
                                },
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(
                      top: 130.h,
                      left: 16.w,
                      right: 16.w,
                    ),
                    child: Obx(() {
                      final isNegative = controller.unallocatedAmount.value < 0;
                      return Stack(
                        children: [
                          Container(
                            width: double.infinity,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            final result = await Get.toNamed(
                                              Routes.WALLETCREATE,
                                              arguments: {'isAdjustMode': true},
                                            );
                                            if (result == true) {
                                              controller.showSuccessMessage(
                                                'Thành công',
                                                'Đã cập nhật ngân sách',
                                              );
                                            }
                                            controller.fetchData();
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16.w,
                                              vertical: 8.h,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: const Color(0xFFC49A45),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                              color: Colors.white.withOpacity(
                                                0.5,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.settings,
                                                  color: const Color(
                                                    0xFFC49A45,
                                                  ),
                                                  size: 16.r,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  "Chỉnh sửa ngân sách",
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(
                                                      0xFFC49A45,
                                                    ),
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
                                      final result = await Get.toNamed(
                                        Routes.BUDGET_DISTRIBUTION,
                                      );
                                      if (result == true) {
                                        if (controller.isOffline) {
                                          controller.showSuccessMessage(
                                            "Đã lưu (Ngoại tuyến)",
                                            "Dữ liệu sẽ được đồng bộ khi có mạng",
                                          );
                                        } else {
                                          controller.showSuccessMessage(
                                            "Thành công",
                                            "Đã lưu cấu hình ngân sách",
                                          );
                                        }
                                      }
                                      controller.fetchData();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF369B56),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                          ),
                          if (isNegative)
                            Positioned(
                              top: 16.w,
                              right: 16.w,
                              child: GestureDetector(
                                onTap: () {
                                  controller.showWarningDialog();
                                },
                                child: Container(
                                  padding: EdgeInsets.all(4.r),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade700,
                                    size: 28.sp,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Obx(() {
                  final count = controller.overspentCategoriesCount;
                  if (count == 0) return const SizedBox.shrink();

                  return Container(
                    margin: EdgeInsets.only(top: 24.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromARGB(255, 247, 180, 192),
                          Color.fromARGB(255, 247, 180, 192),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFE91E63,
                          ).withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16.r),
                        onTap: () {
                          Get.toNamed(Routes.OVERSPENT_LIST);
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                          child: Row(
                            children: [
                              // Icon with circle background
                              Container(
                                padding: EdgeInsets.all(10.r),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                    255,
                                    255,
                                    255,
                                    255,
                                  ).withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  AppAssets.iconWarning,
                                  width: 22.r,
                                  height: 22.r,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 22.r,
                                        color: Colors.orange,
                                      ),
                                ),
                              ),
                              SizedBox(width: 16.w),
                              // Text Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Cần chú ý",
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color.fromARGB(
                                          255,
                                          0,
                                          0,
                                          0,
                                        ).withValues(alpha: 0.7),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      "Có $count danh mục chi tiêu vượt hạn mức",
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF1E1E1E),
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // CTA Chevron
                              Icon(
                                Icons.chevron_right_rounded,
                                color: const Color(
                                  0xFFD81B60,
                                ).withValues(alpha: 0.6),
                                size: 24.r,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 4.h)),

            SliverToBoxAdapter(
              child: Obx(() {
                if (controller.isLoading) {
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
                  return EmptyCategorySuggestionWidget(
                    onSuggestionTap: () async {
                      await Get.toNamed(Routes.CATEGORY);
                      controller.fetchData();
                    },
                  );
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
                          final filteredCategories = group.categories.where((
                            cat,
                          ) {
                            return !controller.budgetService.goals.any(
                              (goal) => goal.categoryId == cat.categoryModel.id,
                            );
                          }).toList();

                          if (filteredCategories.isEmpty)
                            return const SizedBox.shrink();

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
                                children: filteredCategories.map((cat) {
                                  return BudgetCategoryItem(
                                    category: cat,
                                    formattedAllocated: controller
                                        .formatCurrency(cat.allocated),
                                    formattedSpent: controller.formatCurrency(
                                      cat.spent,
                                    ),
                                    formattedRemaining: controller
                                        .formatCurrency(cat.remaining),
                                    onTap: () {
                                      Get.toNamed(
                                        Routes.CATEGORY_DETAIL,
                                        arguments: cat.categoryModel,
                                      );
                                    },
                                    onEdit: () {
                                      Get.toNamed(
                                        Routes.OVERSPENT_COMPENSATION,
                                        arguments: cat.categoryModel,
                                      );
                                    },
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
          ), // End RefreshIndicator
          ), // End Expanded
        ],
      ),
    );
  }
}
