import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:get/get.dart';

import 'package:appintern/ui/controllers/transaction_detail_controller.dart';
import 'package:appintern/core/constants/app_assets.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class TransactionDetailScreen extends GetView<TransactionDetailController> {
  const TransactionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6E9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(4.w),
            decoration: const BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Chi tiết giao dịch",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            if (controller.isLoading || controller.isSystemRollover) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.edit, color: Colors.black54),
              onPressed: () => controller.onEditTransaction(),
            );
          }),
        ],
      ),
      body: Obx(() {
        final tx = controller.rxTransaction.value;
        final detail = controller.detail.value;
        final category = controller.category.value;
        final isExpense = tx.type == 'EXPENSE';
        final sign = isExpense ? '-' : '+';
        final amountColor = isExpense
            ? const Color(0xFFE53935)
            : const Color(0xFF4CAF50);

        String note = "Không có mô tả";
        if (tx.note != null && tx.note!.trim().isNotEmpty) {
          note = tx.note!;
        } else if (detail != null && detail.note.trim().isNotEmpty) {
          note = detail.note;
        }

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Icon & Amount
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: amountColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExpense ? Icons.arrow_outward : Icons.arrow_downward,
                  color: Colors.white,
                  size: 24.w,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                "$sign${CurrencyFormatter.format(tx.amount)}",
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                DateFormat('dd/MM/yyyy').format(tx.transactionDate),
                style: TextStyle(fontSize: 14.sp, color: Colors.black87),
              ),
              SizedBox(height: 32.h),

              // 2. Info Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category
                    if (category != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5D1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: CustomIconWidget(
                              iconName: category.iconName,
                              size: 24.w,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Danh mục",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                    ],

                    // Wallet
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ví",
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              controller.selectedWalletName.value,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    Divider(color: Colors.grey[200]),
                    SizedBox(height: 20.h),

                    // Note
                    Text(
                      "Ghi chú",
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      note,
                      style: TextStyle(fontSize: 15.sp, color: Colors.black87),
                    ),

                    // Images
                    if (detail != null && detail.receiptFileIds.isNotEmpty) ...[
                      SizedBox(height: 20.h),
                      Divider(color: Colors.grey[200]),
                      SizedBox(height: 20.h),
                      Text(
                        "Hình ảnh đính kèm",
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        height: 120.h,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: detail.receiptFileIds.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(width: 12.w),
                          itemBuilder: (context, index) {
                            final fileId = detail.receiptFileIds[index];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: Obx(() {
                                final bytes = controller.imageBytes[fileId];
                                if (bytes == null) {
                                  return Container(
                                    width: 120.w,
                                    height: 120.h,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return Image.memory(
                                  bytes,
                                  width: 120.w,
                                  height: 120.h,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 120.w,
                                      height: 120.h,
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 40.h),

              // 3. Delete Button
              if (!controller.isSystemRollover)
                Obx(
                  () => TextButton(
                    onPressed: controller.isLoading
                        ? null
                        : controller.onDeleteTransaction,
                    child: controller.isLoading
                        ? SizedBox(
                            height: 20.h,
                            width: 20.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFE53935),
                            ),
                          )
                        : Text(
                            "XÓA GIAO DỊCH",
                            style: TextStyle(
                              color: controller.isLoading
                                  ? Colors.grey
                                  : const Color(0xFFE53935),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),
              SizedBox(height: 20.h),
            ],
          ),
        );
      }),
    );
  }
}
