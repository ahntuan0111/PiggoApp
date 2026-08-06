import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:appintern/ui/widgets/bottom_sheet/add_category_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/ui/controllers/category_detail_controller.dart';
import 'package:appintern/ui/widgets/history_transaction_item.dart';
import 'package:appintern/ui/widgets/history_transfer_item.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:appintern/ui/widgets/bottom_sheet/edit_money_distribution.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/widgets/dialogs/confirm_dialog_widget.dart';

class CategoryDetailScreen extends GetView<CategoryDetailController> {
  const CategoryDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(4.r),
            decoration: const BoxDecoration(
              color: Color(0xFFBDBDBD),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 16),
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF8D6E63)),
            onPressed: () {
              Get.bottomSheet(
                AddCategoryBottomSheet(
                  isUpdate: true,
                  initialName: controller.category.name,
                  initialIcon: controller.category.iconName,
                  title: 'Cập nhật danh mục',
                  buttonText: 'CẬP NHẬT',
                  onSave: (name, icon) async {
                    await controller.updateCategory(name, icon);
                  },
                ),
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshAll,
        color: const Color(0xFFFFB74D),
        child: GetBuilder<CategoryDetailController>(
          builder: (_) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tiêu đề: Icon + Tên + Tag
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: controller.category.iconName,
                      size: 24.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        controller.category.name,
                        maxLines: 1, // Giới hạn 1 dòng
                        overflow: TextOverflow
                            .ellipsis, // Thêm "..." nếu text quá dài
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9C4), // Vàng nhạt
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        // Giả định loại là chi tiêu, nếu có categoryType thì map đúng tên
                        'Chi tiêu',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: const Color(0xFFF57F17),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // Card 1: Số tiền phân bổ
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: GetBuilder<CategoryDetailController>(
                    builder: (controller) => Column(
                      children: [
                        _buildMoneyRow(
                          'Số tiền đã phân bổ',
                          CurrencyFormatter.format(
                            controller.category.defaultBudget,
                          ),
                          const Color(0xFF1E1E1E),
                          FontWeight.w500,
                        ),
                        SizedBox(height: 12.h),
                        _buildMoneyRow(
                          'Số tiền đã tiêu',
                          CurrencyFormatter.format(controller.category.spent),
                          const Color(0xFF1E1E1E),
                          FontWeight.w500,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Divider(
                            color: const Color(0xFFEEEEEE),
                            height: 1.h,
                          ),
                        ),
                        _buildMoneyRow(
                          'Còn lại',
                          CurrencyFormatter.format(
                            controller.category.remaining,
                          ),
                          const Color(0xFF43A047), // Màu xanh
                          FontWeight.bold,
                        ),
                        SizedBox(height: 24.h),
                        SizedBox(
                          width: double.infinity,
                          height: 48.h,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFFFFB74D,
                              ), // Vàng cam
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Get.bottomSheet(
                                EditMoneyDistributionBottomSheet(
                                  initialAllocated:
                                      controller.category.defaultBudget,
                                  unallocatedAmount:
                                      controller.unallocatedAmount,
                                  categoryGroups: controller.categoryGroups,
                                  currentCategoryId: controller.category.id,
                                  onSave:
                                      (
                                        newBudget, {
                                        sourceCategoryId,
                                        sourceCategoryNewBudget,
                                        note,
                                      }) async {
                                        await controller.updateBudget(
                                          newBudget,
                                          sourceCategoryId: sourceCategoryId,
                                          sourceCategoryNewBudget:
                                              sourceCategoryNewBudget,
                                        );
                                        if (Get.isBottomSheetOpen == true) {
                                          Get.back(); // close bottom sheet
                                        }
                                      },
                                ),
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                              );
                            },

                            child: Text(
                              'SỬA SỐ TIỀN PHÂN BỔ',
                              style: TextStyle(
                                color: const Color(0xFF1E1E1E),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Card 2: Lịch sử
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lịch sử giao dịch',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Obx(() {
                        if (controller.isLoadingHistory.value) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (controller.historyList.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.h),
                              child: Text(
                                'Chưa có giao dịch nào',
                                style: TextStyle(
                                  color: const Color(0xFF757575),
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          );
                        }

                        // Tính toán số lượng item hiển thị, tối đa là 5
                        int displayCount = controller.historyList.length;
                        if (displayCount > 5) {
                          displayCount = 5;
                        }

                        return Column(
                          children: List.generate(displayCount, (index) {
                            final item = controller.historyList[index];
                            return HistoryTransactionItem(
                              categoryName: item['categoryName'],
                              note: item['note'],
                              walletName: item['walletName'],
                              amount: item['amount'],
                              type: item['type'],
                              date: item['date'],
                            );
                          }),
                        );
                      }),
                      SizedBox(height: 16.h),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Get.toNamed(
                              Routes.TRANSACTION_HISTORY,
                              arguments: {'category': controller.category},
                            );
                          },
                          child: Text(
                            'Xem tất cả',
                            style: TextStyle(
                              color: const Color(0xFF9E9E9E),
                              fontSize: 14.sp,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Card 3: Lịch sử cân bằng ngân sách
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lịch sử cân bằng ngân sách',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Obx(() {
                        if (controller.isLoadingTransferHistory.value) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (controller.transferHistoryList.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.h),
                              child: Text(
                                'Chưa có hoạt động cân bằng nào',
                                style: TextStyle(
                                  color: const Color(0xFF757575),
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: List.generate(
                            controller.transferHistoryList.length,
                            (index) {
                              final item =
                                  controller.transferHistoryList[index];
                              return HistoryTransferItem(
                                action: item['action'],
                                partnerName: item['partnerName'],
                                partnerIcon: item['partnerIcon'],
                                partnerColor: item['partnerColor'],
                                amount: item['amount'],
                                note: item['note'] ?? '',
                                date: item['date'] as DateTime,
                              );
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),

                // Nút xóa
                Obx(
                  () => Container(
                    width: double.infinity,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: TextButton.icon(
                      onPressed: controller.isLoading
                          ? null
                          : () {
                              final hasLinkedGoal = controller.hasLinkedGoal;
                              Get.dialog(
                                ConfirmDialogWidget(
                                  title: 'Xác nhận xóa',
                                  content:
                                      'Bạn có chắc chắn muốn xóa danh mục này không?'
                                      '${hasLinkedGoal ? '\n\nCảnh báo: Danh mục này đang được liên kết với một Mục Tiêu Tiết Kiệm. Việc xóa danh mục sẽ ĐỒNG THỜI XÓA Mục Tiêu Tiết Kiệm đó.' : ''}',
                                  confirmText: 'Xóa',
                                  onConfirm: () {
                                    Get.back();
                                    controller.deleteCategory();
                                  },
                                ),
                              );
                            },
                      icon: controller.isLoading
                          ? SizedBox(
                              height: 20.r,
                              width: 20.r,
                              child: const CircularProgressIndicator(
                                color: Color(0xFFE53935),
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFE53935),
                              size: 20,
                            ),
                      label: Text(
                        'XÓA DANH MỤC',
                        style: TextStyle(
                          color: controller.isLoading
                              ? Colors.grey
                              : const Color(0xFFE53935),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoneyRow(
    String label,
    String value,
    Color valueColor,
    FontWeight valueWeight,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14.sp, color: const Color(0xFF424242)),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: valueColor,
                  fontWeight: valueWeight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
