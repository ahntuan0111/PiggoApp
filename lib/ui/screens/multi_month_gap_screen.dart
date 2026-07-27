import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/rollover_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class MultiMonthGapScreen extends GetView<RolloverController> {
  const MultiMonthGapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1), // Nền Kem
      appBar: AppBar(
        title: Text("Trợ lý ngân sách", style: TextStyle(color: const Color(0xFF0B4A3A), fontWeight: FontWeight.bold, fontSize: 16.sp)),
        centerTitle: true,
        automaticallyImplyLeading: false, // Ngăn back
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: () {},
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Illustration (Piggy Bank)
              Container(
                height: 200.h,
                width: 250.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.savings, size: 100.sp, color: const Color(0xFFC49A45)), // Placeholder cho hình Heo đất
                ),
              ),
              SizedBox(height: 40.h),
              
              Text(
                "Mừng bạn đã quay trở lại!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B4A3A), // Xanh rêu
                ),
              ),
              SizedBox(height: 16.h),
              
              Obx(() => RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: "Dữ liệu của bạn đã dừng ở "),
                    TextSpan(text: controller.lastActiveMonthYear.value.isNotEmpty ? controller.lastActiveMonthYear.value : "Tháng cũ", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B4A3A))),
                    const TextSpan(text: ". Để tránh rắc rối sổ sách, hệ thống đã gom tất cả số dư đang treo lại. Hãy bắt đầu một trang mới cho "),
                    TextSpan(text: controller.currentMonthYear.value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF369B56))),
                    const TextSpan(text: " nhé!"),
                  ],
                ),
              )),
              
              SizedBox(height: 32.h),
              
              // Total Treo Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7F1),
                  borderRadius: BorderRadius.circular(30.r),
                  border: Border.all(color: const Color(0xFFC49A45).withValues(alpha: 0.3), width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: const Color(0xFFC49A45), size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(
                      "TỔNG QUỸ TREO",
                      style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12.sp),
                    ),
                    SizedBox(width: 12.w),
                    Obx(() => Text(
                      "${formatter.format(controller.totalGapBalance.value)}đ",
                      style: TextStyle(color: const Color(0xFF0B4A3A), fontWeight: FontWeight.w900, fontSize: 16.sp),
                    )),
                  ],
                ),
              ),
              
              SizedBox(height: 48.h),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 60.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B4A3A), // Xanh rêu
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF0B4A3A).withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    Get.toNamed('/rollover_new_month');
                  },
                  child: Obx(() => Text(
                    "Làm mới & Bắt đầu ${controller.currentMonthYear.value}",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )),
                ),
              ),
              
              SizedBox(height: 24.h),
              
              TextButton(
                onPressed: () {},
                child: Text(
                  "Xem lại lịch sử cũ",
                  style: TextStyle(color: Colors.black54, fontSize: 13.sp, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
