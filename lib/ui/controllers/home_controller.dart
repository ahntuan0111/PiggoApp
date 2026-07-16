import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/ui/widgets/dialogs/budget_warning_dialog.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/data/models/budget_category_group.dart';
import 'package:appintern/domain/repositories/auth_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';

class HomeController extends BaseController with BudgetAware {
  final storage = Get.find<StorageService>();

  var userName = "Đang tải...".obs;

  RxDouble get totalWalletBalance => budgetService.totalWalletBalance;
  RxDouble get allocatedAmount => budgetService.allocatedAmount;
  RxDouble get unallocatedAmount => budgetService.unallocatedAmount;

  RxList<BudgetCategory> get categories => budgetService.categories;
  RxList<BudgetCategoryGroup> get categoryGroups =>
      budgetService.categoryGroups;

  int get overspentCategoriesCount {
    return categories.where((cat) => cat.remaining < 0).length;
  }

  final currentMonth = 'Tháng 7 2026'.obs;

  @override
  void onInit() {
    super.onInit();
    userName.value = storage.read(AppKeys.userName) ?? "Đang tải...";

    // Listen to BudgetService loading state to show/hide loading indicator
    ever(budgetService.isDataLoaded, (loaded) {
      if (loaded) hideLoading();
    });

    ever(budgetService.isError, (error) {
      if (error) {
        hideLoading();
        showErrorMessage(
          "Lỗi",
          "Không thể tải dữ liệu trang chủ: ${budgetService.errorMessage.value}",
        );
      }
    });
  }

  @override
  void onReady() {
    super.onReady();
    _verifySessionAndFetchData();
  }

  Future<void> _verifySessionAndFetchData() async {
    if (!budgetService.isDataLoaded.value) {
      showLoading();
    }
    
    // Kiểm tra xem session thực sự còn hiệu lực trên Appwrite Server hiện tại không
    // Việc này rất quan trọng khi thay đổi IP localhost
    final authRepo = Get.find<AuthRepository>();
    final sessionResult = await ErrorHandler.execute(
      () async => await authRepo.getUser(),
      tag: 'VERIFY_SESSION',
    );
    
    await sessionResult.fold(
      (failure) async {
        // Session không hợp lệ (IP thay đổi, cookie mất, v.v.)
        hideLoading();
        storage.clearAll();
        Get.offAllNamed(Routes.ONBOARDING);
        Get.snackbar(
          "Phiên đăng nhập hết hạn", 
          "Vui lòng đăng nhập lại (Do IP máy chủ thay đổi hoặc phiên hết hạn).",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      },
      (user) async {
        // Nếu session hợp lệ, tải dữ liệu
        if (!budgetService.isDataLoaded.value) {
          await budgetService.refreshData();
        }
      },
    );
  }

  Future<void> fetchData() async {
    await budgetService.refreshData();
  }

  // Hàm tiện ích format tiền tệ (thay cho thư viện intl để giữ app nhẹ)
  String formatCurrency(double amount) {
    String numStr = amount.toStringAsFixed(0);
    return numStr.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        ) +
        'đ';
  }

  void showWarningDialog() {
    Get.dialog(BudgetWarningDialog(unallocatedAmount: unallocatedAmount.value));
  }
}
