import "package:flutter/material.dart";
import "package:get/get.dart";
import "package:flutter_screenutil/flutter_screenutil.dart";
import '../controllers/onboarding_controller.dart';
import 'package:appintern/core/constants/app_assets.dart';
import 'package:appintern/core/routes/app_routes.dart';

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
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.broken_image,
                          size: 100.w,
                          color: Colors.grey,
                        ),
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
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: [
                    // Nút Đăng ký tài khoản mới (Primary)
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: () => Get.toNamed(Routes.REGISTER),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Đăng ký tài khoản mới',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Nút Đăng nhập (Outlined)
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: OutlinedButton(
                        onPressed: () => Get.toNamed(Routes.LOGIN),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4285F4),
                          side: const BorderSide(color: Color(0xFF4285F4), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Đăng nhập với tài khoản',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[400], thickness: 0.8)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: Text(
                            'Hoặc tiếp tục với',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF757575),
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[400], thickness: 0.8)),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Nút Google Sign In
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: Obx(
                        () => OutlinedButton(
                          onPressed: controller.isLoading || controller.isGoogleLoading.value
                              ? null
                              : () => controller.loginWithGoogle(),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey[300]!, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: controller.isGoogleLoading.value
                              ? SizedBox(
                                  width: 24.w,
                                  height: 24.h,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.g_mobiledata,
                                      color: Color(0xFF4285F4),
                                      size: 30,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Đăng nhập bằng Google',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1E1E1E),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
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
