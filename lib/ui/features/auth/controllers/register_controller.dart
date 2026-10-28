import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/data/repositories/auth_repository.dart';
import 'package:appintern/core/services/budget_service.dart';

class RegisterController extends BaseController {
  final AuthRepository authRepo = Get.find<AuthRepository>();

  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final isPasswordVisible = false.obs;
  final isConfirmVisible = false.obs;

  @override
  void onClose() {
    nameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmVisibility() {
    isConfirmVisible.value = !isConfirmVisible.value;
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;

    if (name.isEmpty) {
      showErrorMessage("Lỗi nhập liệu", "Vui lòng nhập Họ và tên.");
      return;
    }
    if (username.isEmpty) {
      showErrorMessage("Lỗi nhập liệu", "Vui lòng nhập Tên đăng nhập.");
      return;
    }
    if (username.length < 3) {
      showErrorMessage("Lỗi nhập liệu", "Tên đăng nhập phải có ít nhất 3 ký tự.");
      return;
    }
    if (username.contains(' ')) {
      showErrorMessage("Lỗi nhập liệu", "Tên đăng nhập không được chứa khoảng trắng.");
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(username)) {
      showErrorMessage("Lỗi nhập liệu", "Tên đăng nhập chỉ được chứa chữ cái, số, dấu chấm, gạch dưới hoặc gạch ngang.");
      return;
    }
    if (password.length < 6) {
      showErrorMessage("Lỗi nhập liệu", "Mật khẩu phải có ít nhất 6 ký tự để đảm bảo an toàn.");
      return;
    }
    if (password != confirm) {
      showErrorMessage("Lỗi nhập liệu", "Mật khẩu xác nhận không khớp.");
      return;
    }

    showLoading();

    final result = await ErrorHandler.execute(
      () => authRepo.registerWithPassword(
        username: username,
        password: password,
        fullName: name,
      ),
      tag: "REGISTER_USER",
    );

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Đăng ký thất bại", failure.message);
      },
      (profile) async {
        showSuccessMessage("Thành công", "Đã tạo tài khoản thành công!");
        await Get.find<BudgetService>().refreshData();
        Get.offAllNamed(Routes.MAIN);
      },
    );
  }
}
