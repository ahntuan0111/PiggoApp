import "package:flutter/material.dart";
import "package:get/get.dart";
import "package:flutter_screenutil/flutter_screenutil.dart";
import '../controllers/onboarding_controller.dart';
import 'package:appintern/core/constants/app_assets.dart';

class OnboardingScreen extends GetView<OnboardingController> {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: 32.h), // Figma: padding bottom 32px
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // 296×321, top:50, left:33
                    Positioned(
                      top: 26.h,
                      left: 33.w,
                      child: Image.asset(
                        AppAssets.imageOnboarding,
                        width: 296.w,
                        height: 321.h,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.broken_image, size: 100.w, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  "Quản lý chi tiêu thông minh\n& Tự do tài chính",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(
                      0xFF1E1E1E,
                    ), // Chữ tối màu dễ đọc trên nền sáng
                    fontFamily: 'Roboto',
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    height: 32 / 24,
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                ), // (360-328)/2=16
                child: SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: Obx(
                    () => ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.loginWithGoogle(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        disabledBackgroundColor: const Color(
                          0xFF4285F4,
                        ).withOpacity(0.6),
                      ),
                      child: controller.isLoading.value
                          ? SizedBox(
                              width: 24.w,
                              height: 24.h,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Đăng nhập bằng Google',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                height: 24 / 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24.h), // Figma gap: 24px
              // Terms text
              const TermsAndPrivacyText(),
            ],
          ),
        ),
      ),
    );
  }
}

class TermsAndPrivacyText extends StatelessWidget {
  const TermsAndPrivacyText({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w), // (360-279)/2 ≈ 40
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            color: const Color(0xFF616161),
            fontFamily: 'Poppins',
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            height: 22 / 12,
          ),
          children: [
            const TextSpan(text: 'Bằng việc tiếp tục, bạn đồng ý với '),
            TextSpan(
              text: 'Điều khoản dịch vụ',
              style: TextStyle(
                color: const Color(0xFF1E1E1E),
                decoration: TextDecoration.underline,
                fontSize: 12.sp,
                height: 22 / 12,
              ),
            ),
            const TextSpan(text: ' và '),
            TextSpan(
              text: 'Chính sách bảo mật.',
              style: TextStyle(
                color: const Color(0xFF1E1E1E),
                decoration: TextDecoration.underline,
                fontSize: 12.sp,
                height: 22 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
