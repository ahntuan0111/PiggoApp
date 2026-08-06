import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class OfflineQueueFullDialog extends StatelessWidget {
  final int currentCount;
  final int maxCount;
  final bool isAiTask;

  const OfflineQueueFullDialog({
    super.key,
    required this.currentCount,
    required this.maxCount,
    required this.isAiTask,
  });

  static void show({
    required int currentCount,
    required int maxCount,
    required bool isAiTask,
  }) {
    Get.dialog(
      OfflineQueueFullDialog(
        currentCount: currentCount,
        maxCount: maxCount,
        isAiTask: isAiTask,
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: Colors.white,
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Icon Cảnh báo (Header) trong Container bo góc
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFEBC14F,
                ).withOpacity(0.15), // Màu vàng cam nhạt
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 32.w,
                color: const Color(0xFFEBC14F), // Màu vàng cam chủ đạo
              ),
            ),
            SizedBox(height: 24.h),

            // 2. Tiêu đề (Title)
            Text(
              "Hàng chờ ngoại tuyến đã đầy!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 12.h),

            // 3. Nội dung giải thích (Body Text)
            Text(
              "$currentCount/$maxCount giao dịch đang chờ. Vui lòng kết nối Internet để tiếp tục.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black.withOpacity(0.6),
                height: 1.4,
              ),
            ),
            SizedBox(height: 32.h),

            // 4. Khu vực Nút bấm (Actions)
            // Nút Chính: Thử lại kết nối
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFEBC14F,
                  ), // Màu chủ đạo của App
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Đã hiểu",
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
