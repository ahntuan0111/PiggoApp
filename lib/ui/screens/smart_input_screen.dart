import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/smart_input_controller.dart';

class SmartInputScreen extends GetView<SmartInputController> {
  const SmartInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E)),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Nhập giao dịch nhanh",
          style: TextStyle(
            color: const Color(0xFF1E1E1E),
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 64.r,
                  color: const Color(0xFFEBC14F),
                ),
                SizedBox(height: 24.h),
                Text(
                  "Kể cho tôi nghe về giao dịch của bạn",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "AI sẽ tự động nhận diện số tiền và danh mục",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 32.h),
                Obx(
                  () => TextField(
                    controller: controller.textController,
                    autofocus: true,
                    enabled: !controller.isProcessing.value,
                    maxLines: null,
                    minLines: 2,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => controller.submitTextInput(),
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: const Color(0xFF1E1E1E),
                    ),
                    decoration: InputDecoration(
                      hintText: "VD: Đổ xăng hết 50 cành...",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16.sp,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: const BorderSide(
                          color: Color(0xFFEBC14F),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 16.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Obx(
                  () => SizedBox(
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: controller.isProcessing.value
                          ? null
                          : () => controller.submitTextInput(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF9C03C),
                        disabledBackgroundColor: const Color(
                          0xFFF9C03C,
                        ).withValues(alpha: 0.5),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: controller.isProcessing.value
                          ? SizedBox(
                              width: 24.r,
                              height: 24.r,
                              child: const CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.send,
                                  color: Color(0xFF2E2E2E),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  "Gửi",
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2E2E2E),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
