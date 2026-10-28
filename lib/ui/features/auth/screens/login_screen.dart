import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../controllers/login_controller.dart';
import 'package:appintern/core/routes/app_routes.dart';

class LoginScreen extends GetView<LoginController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            size: 20.sp,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Đăng nhập",
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "Đăng nhập vào tài khoản trên thiết bị của bạn",
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14.sp,
                  color: isDark ? const Color(0xFFA0A0A0) : const Color(0xFF616161),
                ),
              ),
              SizedBox(height: 36.h),

              // Tên đăng nhập
              _buildInputField(
                context: context,
                controller: controller.usernameController,
                label: "Tên đăng nhập",
                hint: "Nhập tên đăng nhập của bạn",
                icon: Icons.alternate_email,
              ),
              SizedBox(height: 20.h),

              // Mật khẩu
              Obx(
                () => _buildInputField(
                  context: context,
                  controller: controller.passwordController,
                  label: "Mật khẩu",
                  hint: "Nhập mật khẩu",
                  icon: Icons.lock_outline,
                  obscureText: !controller.isPasswordVisible.value,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.isPasswordVisible.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey,
                      size: 20.sp,
                    ),
                    onPressed: controller.togglePasswordVisibility,
                  ),
                ),
              ),
              SizedBox(height: 36.h),

              // Nút Đăng nhập
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: controller.isLoading ? null : controller.login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: controller.isLoading
                        ? SizedBox(
                            width: 24.w,
                            height: 24.h,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Đăng Nhập",
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Chuyển sang màn đăng ký
              Center(
                child: GestureDetector(
                  onTap: () => Get.offNamed(Routes.REGISTER),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14.sp,
                        color: isDark ? const Color(0xFFA0A0A0) : const Color(0xFF616161),
                      ),
                      children: const [
                        TextSpan(text: "Chưa có tài khoản? "),
                        TextSpan(
                          text: "Đăng ký ngay",
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF424242),
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(
            fontSize: 15.sp,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14.sp,
              color: isDark ? const Color(0xFF666666) : const Color(0xFF9E9E9E),
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF4285F4), size: 20.sp),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF4285F4), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
