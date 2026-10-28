import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/data/repositories/auth_repository.dart';
import 'package:appintern/core/services/budget_service.dart';

class LoginController extends BaseController {
  final AuthRepository authRepo = Get.find<AuthRepository>();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  final isPasswordVisible = false.obs;

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      showErrorMessage("Lỗi nhập liệu", "Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.");
      return;
    }

    showLoading();

    final result = await ErrorHandler.execute(
      () => authRepo.loginWithPassword(
        username: username,
        password: password,
      ),
      tag: "LOGIN_USER",
    );

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Đăng nhập thất bại", failure.message);
      },
      (profile) async {
        showSuccessMessage("Thành công", "Đăng nhập thành công!");
        await Get.find<BudgetService>().refreshData();
        Get.offAllNamed(Routes.MAIN);
      },
    );
  }
}
