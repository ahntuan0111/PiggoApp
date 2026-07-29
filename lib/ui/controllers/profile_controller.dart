import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/data/repositories/auth_repository.dart';
import 'package:appintern/data/repositories/rollover_repository.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/constants/app_keys.dart';

class ProfileController extends BaseController {
  final AuthRepository authRepository = Get.find<AuthRepository>();
  final StorageService storageService = Get.find<StorageService>();
  final CategoryRepository categoryRepo = Get.find<CategoryRepository>();

  Future<void> logout() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      await authRepository.logout();
    }, tag: 'LOGOUT');
    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage('Lỗi đăng xuất', failure.message);
      },
      (data) {
        storageService.clearAll();
        Get.offAllNamed(Routes.ONBOARDING);
      },
    );
  }

  Future<void> resetAllData() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      await authRepository.clearAllUserData();
      await authRepository.logout();
    }, tag: 'RESET_ALL_DATA');
    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage('Lỗi reset dữ liệu', failure.message);
      },
      (data) {
        storageService.clearAll();
        Get.offAllNamed(Routes.ONBOARDING);
        Get.snackbar(
          'Thành công',
          'Đã xóa sạch dữ liệu. Vui lòng đăng nhập lại để bắt đầu từ đầu.',
          backgroundColor: const Color(0xFF369B56),
          colorText: const Color(0xFFFFFFFF),
        );
      },
    );
  }

  Future<void> resetAccountData() async {
    showLoading();
    final String? userId = storageService.read<String>(AppKeys.userId);

    final result = await ErrorHandler.execute(() async {
      // 1. Xóa sạch mọi bảng dữ liệu của user (CategoryTypes, Categories, Budgets, Summaries, Wallets, Transactions, v.v...)
      await authRepository.clearAllUserData();

      // 2. Tạo lại Category Types mặc định cho user
      if (userId != null && userId.isNotEmpty) {
        await categoryRepo.createDefaultCategoryTypes(userId);
      }
    }, tag: 'RESET_ACCOUNT_DATA');
    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage('Lỗi reset dữ liệu', failure.message);
      },
      (data) async {
        final budgetService = Get.find<BudgetService>();
        await budgetService.refreshData();

        Get.snackbar(
          'Thành công',
          'Đã reset toàn bộ dữ liệu về trạng thái ban đầu.',
          backgroundColor: const Color(0xFF369B56),
          colorText: const Color(0xFFFFFFFF),
        );

        // Điều hướng về Home (Main) để kích hoạt giao diện trống
        Get.offAllNamed(Routes.MAIN);
      },
    );
  }
}
