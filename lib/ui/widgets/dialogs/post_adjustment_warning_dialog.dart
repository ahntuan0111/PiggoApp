import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostAdjustmentWarningDialog {
  static void show(VoidCallback onConfirm) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8.w),
            const Expanded(
              child: Text(
                "Tháng đã chốt sổ",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          "Giao dịch này thuộc về tháng mà bạn đã chốt sổ.\n\nNó sẽ được ghi nhận vào tháng hiện tại như một khoản 'Điều chỉnh bổ sung' để không làm sai lệch báo cáo cũ.\n\nBạn có muốn tiếp tục lưu?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Tiếp tục lưu"),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
