import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/features/transaction/controllers/transaction_create_controller.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class TransactionCreateScreen extends GetView<TransactionCreateController> {
  const TransactionCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1), // Nền chuẩn sáng
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F7F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E)),
          onPressed: () => Get.back(),
        ),
        title: Obx(
          () => Text(
            controller.isEdit.value ? 'Chỉnh sửa giao dịch' : 'Thêm giao dịch',
            style: TextStyle(
              color: const Color(0xFF1E1E1E),
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount Input
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 220
                                  .w, // Tăng chiều dài để nhập được 9-10 số (100.000.000)
                              child: TextField(
                                controller: controller.amountController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  CurrencyFormatter(),
                                ],
                                style: TextStyle(
                                  color: const Color(0xFF4ADE80),
                                  fontSize: 28
                                      .sp, // Giảm từ 32 xuống 28 để dễ nhìn và đủ chỗ
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  hintStyle: TextStyle(
                                    color: const Color(
                                      0xFF4ADE80,
                                    ).withValues(alpha: 0.5),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Padding(
                              padding: EdgeInsets.only(bottom: 6.h),
                              child: Text(
                                CurrencyFormatter.symbol,
                                style: TextStyle(
                                  color: const Color(0xFF4ADE80),
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 220.w,
                          height: 1,
                          color: const Color(
                            0xFFE57373,
                          ), // Red underline like image
                        ),
                        SizedBox(height: 8.h),
                        Obx(
                          () => controller.isValidAmount.value
                              ? const SizedBox()
                              : Text(
                                  'Số tiền đã nhập không hợp lệ',
                                  style: TextStyle(
                                    color: const Color(0xFFE57373),
                                    fontSize: 12.sp,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Wallet Selection
                  Text(
                    'Tài khoản',
                    style: TextStyle(
                      color: const Color(0xFF757575),
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Obx(
                    () => GestureDetector(
                      onTap: () {
                        // TODO: Open Wallet Picker BottomSheet
                      },
                      child: Text(
                        controller.selectedWalletName.value,
                        style: TextStyle(
                          color: const Color(0xFF1E1E1E),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Category Selection
                  Text(
                    'Danh mục',
                    style: TextStyle(
                      color: const Color(0xFF757575),
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Obx(() {
                    final selectedCat = controller
                        .selectedCategory
                        .value; // Khai báo ngoài builder để Obx track sự thay đổi
                    if (controller.categories.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4ADE80),
                        ),
                      );
                    }
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 16.w,
                        mainAxisSpacing: 16.h,
                      ),
                      itemCount: controller.categories.length,
                      itemBuilder: (context, index) {
                        final cat = controller.categories[index];
                        final isSelected =
                            selectedCat?.categoryModel.id ==
                            cat.categoryModel.id;

                        return GestureDetector(
                          behavior: HitTestBehavior
                              .opaque, // Đảm bảo bắt được mọi tap
                          onTap: () {
                            controller.selectedCategory.value = cat;
                          },
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 48
                                        .w, // Cố định kích thước để không bị lỗi Overflow
                                    height: 48.w,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFF9800).withValues(
                                              alpha: 0.15,
                                            ) // Nền cam nhạt hơn
                                          : Color(
                                              int.parse(
                                                '0xFF${cat.categoryModel.color.toUpperCase().replaceAll('0XFF', '').replaceAll('#', '')}',
                                              ),
                                            ).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFFF9800)
                                            : Colors
                                                  .transparent, // Viền cam nhạt
                                        width: isSelected ? 2.w : 0,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFFFF9800,
                                                ).withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: CustomIconWidget(
                                        iconName: cat.icon,
                                        size: isSelected
                                            ? 24.sp
                                            : 20.sp, // Phóng to nhẹ icon bên trong
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        padding: EdgeInsets.all(2.w),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF9800),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 10.sp,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF1E1E1E)
                                        : const Color(0xFF616161),
                                    fontSize: 12.sp,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }),

                  // Chi tiết Category được chọn
                  Obx(() {
                    if (controller.selectedCategory.value != null) {
                      final isOver = controller.isOverBudget;
                      final progressColor = isOver
                          ? Colors.red
                          : const Color(
                              0xFF4CAF50,
                            ); // Màu xanh đậm hơn chút cho dễ nhìn

                      return Container(
                        margin: EdgeInsets.only(top: 16.h, bottom: 24.h),
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color:
                              Colors.white, // Thay màu nền đậm thành màu trắng
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                          ), // Viền nhẹ
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
                                      'Đã tiêu',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: const Color(0xFF757575),
                                      ),
                                    ),
                                    Text(
                                      controller.formatCurrency(
                                        controller.currentSpent,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1E1E1E),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Còn lại',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: const Color(0xFF757575),
                                      ),
                                    ),
                                    Text(
                                      controller.formatCurrency(
                                        controller.currentRemaining,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: progressColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            LinearProgressIndicator(
                              value: controller.currentProgress,
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.1,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progressColor,
                              ),
                              minHeight: 6.h,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox();
                  }),

                  SizedBox(height: 24.h),

                  // Date
                  Obx(() {
                    final today = DateTime.now();
                    final yesterday = today.subtract(const Duration(days: 1));
                    final twoDaysAgo = today.subtract(const Duration(days: 2));

                    Widget buildDateOption(DateTime date, String label) {
                      final isSelected = controller.isSameDay(
                        controller.selectedDate.value,
                        date,
                      );
                      return GestureDetector(
                        onTap: () => controller.setDate(date),
                        child: Container(
                          margin: EdgeInsets.only(right: 8.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4CAF50)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('dd/M').format(date),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF757575),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF757575),
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Kiểm tra xem ngày hiện tại có nằm trong 3 ngày gợi ý không
                    bool isCustomDate =
                        !controller.isSameDay(
                          controller.selectedDate.value,
                          today,
                        ) &&
                        !controller.isSameDay(
                          controller.selectedDate.value,
                          yesterday,
                        ) &&
                        !controller.isSameDay(
                          controller.selectedDate.value,
                          twoDaysAgo,
                        );

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (isCustomDate)
                                  buildDateOption(
                                    controller.selectedDate.value,
                                    'đã chọn',
                                  ),
                                buildDateOption(today, 'hôm nay'),
                                buildDateOption(yesterday, 'hôm qua'),
                                buildDateOption(twoDaysAgo, 'hai ngày trư..'),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        GestureDetector(
                          onTap: () => controller.pickDate(context),
                          child: Icon(
                            Icons.calendar_month,
                            color: const Color(0xFF4CAF50),
                            size: 28.sp,
                          ),
                        ),
                      ],
                    );
                  }),
                  SizedBox(height: 24.h),

                  // Note
                  Text(
                    'Ghi chú',
                    style: TextStyle(
                      color: const Color(0xFF757575),
                      fontSize: 14.sp,
                    ),
                  ),
                  TextField(
                    controller: controller.noteController,
                    style: TextStyle(
                      color: const Color(0xFF1E1E1E),
                      fontSize: 14.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ghi chú',
                      hintStyle: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF4ADE80)),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Images
                  Text(
                    'Ảnh',
                    style: TextStyle(
                      color: const Color(0xFF757575),
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Obx(
                    () => Row(
                      children: List.generate(3, (index) {
                        if (index < controller.imagePaths.length) {
                          return Container(
                            margin: EdgeInsets.only(right: 12.w),
                            width: 80.w,
                            height: 80.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              image: DecorationImage(
                                image: FileImage(
                                  File(controller.imagePaths[index]),
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.topRight,
                              child: GestureDetector(
                                onTap: () => controller.removeImage(index),
                                child: Container(
                                  margin: EdgeInsets.all(4.w),
                                  padding: EdgeInsets.all(2.w),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16.sp,
                                  ),
                                ),
                              ),
                            ),
                          );
                        } else {
                          return GestureDetector(
                            onTap: () => controller.pickImage(),
                            child: Container(
                              margin: EdgeInsets.only(right: 12.w),
                              width: 80.w,
                              height: 80.w,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE0E0E0,
                                ), // Nền xám nhạt cho nút thêm ảnh
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.add,
                                  color: const Color(0xFF616161),
                                  size: 32.sp,
                                ), // Icon màu xám đậm
                              ),
                            ),
                          );
                        }
                      }),
                    ),
                  ),
                  SizedBox(height: 100.h), // Spacing for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        color: const Color(0xFFF9F7F1),
        padding: EdgeInsets.all(16.w),
        child: Obx(() {
          if (controller.isEdit.value) {
            return SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.isLoading
                    ? null
                    : () => controller.addTransaction(closeAfterSave: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC49A45),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                ),
                child: controller.isLoading
                    ? SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.w,
                        ),
                      )
                    : Text(
                        'Cập nhật',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            );
          } else {
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.isLoading
                        ? null
                        : () =>
                              controller.addTransaction(closeAfterSave: false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC49A45)),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                    ),
                    child: Text(
                      'Lưu & Tiếp tục',
                      style: TextStyle(
                        color: const Color(0xFFC49A45),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: controller.isLoading
                        ? null
                        : () => controller.addTransaction(closeAfterSave: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC49A45),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                    ),
                    child: controller.isLoading
                        ? SizedBox(
                            width: 24.w,
                            height: 24.w,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.w,
                            ),
                          )
                        : Text(
                            'Lưu',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }
}
