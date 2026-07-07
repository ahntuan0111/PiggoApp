import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:appintern/ui/controllers/wallet_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/ui/widgets/emoji_picker_bottom_sheet.dart';

class WalletCreateScreen extends GetView<WalletController> {
  const WalletCreateScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F0), // Nền kem sáng nhạt
      body: SafeArea(
        child: SingleChildScrollView(
          // Thêm scroll view để không lỗi overflow khi bàn phím đẩy lên
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

              // 2. Tiêu đề
              Text(
                'Tạo ví thanh toán',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              SizedBox(height: 24.h),

              // 3. Thay đổi biểu tượng
              Row(
                children: [
                  Obx(
                    () => Container(
                      width: 56.r,
                      height: 56.r,
                      decoration: BoxDecoration(
                        color: const Color(0xFF369B56), // Màu xanh lá
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: Text(
                          controller.selectedIcon.value,
                          style: TextStyle(fontSize: 28.sp),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  InkWell(
                    onTap: () {
                      Get.bottomSheet(
                        EmojiPickerBottomSheet(
                          selectedIcon: controller.selectedIcon,
                        ),
                        backgroundColor: Colors.transparent,
                      );
                    },
                    child: Text(
                      "Thay đổi biểu tượng",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFC49A45),
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFFC49A45),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // 4. Loại ví (Tạm thời là dummy text field)
              Text(
                'Loại ví',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF4A4A4A),
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tài khoản thanh toán',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16.r,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // 5. Tên ví
              Text(
                'Tên của ví này',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF4A4A4A),
                ),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: controller.nameController,
                decoration: InputDecoration(
                  hintText: 'Tên ví (vd: Tiền mặt, tài khoản Tech,...)',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16.sp),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
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
                    borderSide: const BorderSide(color: Color(0xFFF9C03C)),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // 6. Số dư
              Text(
                'Hiện tại số dư trong ví của bạn là bao nhiêu?',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF4A4A4A),
                ),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: controller.balanceController,
                keyboardType: TextInputType.number, // Đổi thành bàn phím số
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Chỉ cho nhập số
                  CurrencyFormatter(), // Formatter ta vừa tạo
                ],
                style: TextStyle(fontSize: 16.sp),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.black, fontSize: 16.sp),
                  prefixText: 'đ ',
                  prefixStyle: TextStyle(
                    color: Colors.black,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
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
                    borderSide: const BorderSide(color: Color(0xFFF9C03C)),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Bạn nhập số tiền càng chính xác thì chúng tôi có thể giúp bạn cập nhật ngân sách càng chính xác hơn.',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
              SizedBox(height: 24.h),

              // 7. Ví mặc định
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ví mặc định',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Ví mặc định là ví sẽ được mặc định lựa chọn khi bạn tạo các giao dịch.',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF4A4A4A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Obx(
                      () => Switch(
                        value: controller.isDefault.value,
                        onChanged: (val) {
                          controller.isDefault.value = val;
                        },
                        activeColor: Colors.white,
                        activeTrackColor: const Color(0xFFF9C03C),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),

              // 8. Nút LƯU VÍ
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: () {
                    controller.onSumbitCreateWallet();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9C03C), // Màu vàng
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "LƯU VÍ",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E2E2E),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }
}
