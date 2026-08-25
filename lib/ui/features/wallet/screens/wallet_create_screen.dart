import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:appintern/ui/features/wallet/controllers/wallet_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/widgets/emoji_picker_bottom_sheet.dart';

class WalletCreateScreen extends GetView<WalletController> {
  const WalletCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F0), // Nền kem sáng nhạt
      body: SafeArea(child: _buildAdjustMode()),
    );
  }

  Widget _buildAdjustMode() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Nút X
          InkWell(
            onTap: () => Get.back(),
            child: Container(
              padding: EdgeInsets.all(8.r),
              decoration: const BoxDecoration(
                color: Color(0xFFD3CFC6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: Colors.white, size: 20.r),
            ),
          ),
          SizedBox(height: 20.h),

          Text(
            'Điều chỉnh ngân sách',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          SizedBox(height: 24.h),

          // Card Tổng ngân sách hiện tại & RealTime sau điều chỉnh
          Obx(() {
            final current = controller.currentTotalBalance;
            final newTotal = controller.newTotalBalance;
            final isAdding = controller.isAdding.value;
            final amount = controller.inputAmount.value;

            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE0E0E0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng ngân sách hiện tại:',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF616161),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(current),
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  const Divider(height: 1),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAdding ? Icons.trending_up : Icons.trending_down,
                            size: 18.sp,
                            color: isAdding
                                ? const Color(0xFF369B56)
                                : Colors.red.shade600,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Tổng ngân sách mới:',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        CurrencyFormatter.format(newTotal),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: newTotal < 0
                              ? Colors.red.shade700
                              : (isAdding && amount > 0
                                    ? const Color(0xFF369B56)
                                    : const Color(0xFF1E1E1E)),
                        ),
                      ),
                    ],
                  ),
                  if (amount > 0) ...[
                    SizedBox(height: 4.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        isAdding
                            ? '(+ ${CurrencyFormatter.format(amount)} đ)'
                            : '(- ${CurrencyFormatter.format(amount)} đ)',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: isAdding
                              ? const Color(0xFF369B56)
                              : Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          SizedBox(height: 20.h),

          // Tabs: Thêm vào / Trừ đi
          Obx(() {
            final current = controller.currentTotalBalance;
            final isZero = current <= 0;

            return Container(
              height: 40.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => controller.isAdding.value = true,
                      child: Container(
                        decoration: BoxDecoration(
                          color: controller.isAdding.value
                              ? const Color(0xFF369B56)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+ Thêm Thu Nhập',
                          style: TextStyle(
                            color: controller.isAdding.value
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: isZero
                          ? null
                          : () => controller.isAdding.value = false,
                      child: Container(
                        decoration: BoxDecoration(
                          color: !controller.isAdding.value
                              ? Colors.red.shade500
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '- Điều Chỉnh Giảm',
                          style: TextStyle(
                            color: isZero
                                ? Colors.grey.shade400
                                : (!controller.isAdding.value
                                      ? Colors.white
                                      : Colors.grey.shade600),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 24.h),

          // Số tiền
          Text(
            'Số tiền',
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF4A4A4A)),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: controller.balanceController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyFormatter(),
            ],
            style: TextStyle(
              fontSize: 16.sp,
              color: controller.isAdding.value
                  ? const Color(0xFF369B56)
                  : Colors.red.shade600,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: 'đ ',
              prefixStyle: TextStyle(
                color: controller.isAdding.value
                    ? const Color(0xFF369B56)
                    : Colors.red.shade600,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
              filled: true,
              fillColor: Colors.white,
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
                borderSide: BorderSide(
                  color: controller.isAdding.value
                      ? const Color(0xFF369B56)
                      : Colors.red.shade500,
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Ghi chú
          Text(
            'Ghi chú (Tùy chọn)',
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF4A4A4A)),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: controller.noteController,
            decoration: InputDecoration(
              hintText: controller.isAdding.value
                  ? 'Ví dụ: Lương tháng 7'
                  : 'Ví dụ: Đánh rơi tiền',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 16.sp),
              filled: true,
              fillColor: Colors.white,
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
                borderSide: const BorderSide(color: Color(0xFFF9C03C)),
              ),
            ),
          ),
          SizedBox(height: 32.h),

          // Lưu
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: Obx(
              () => ElevatedButton(
                onPressed: controller.isLoading
                    ? null
                    : () => controller.adjustBudget(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9C03C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: controller.isLoading
                    ? SizedBox(
                        height: 24.h,
                        width: 24.h,
                        child: const CircularProgressIndicator(
                          color: Color(0xFF2E2E2E),
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        "LƯU LẠI",
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E2E2E),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
