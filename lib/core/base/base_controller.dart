import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/enums/ui_state.dart';

abstract class BaseController extends GetxController {
  // ✅ UIState thống nhất — nguồn sự thật duy nhất
  final uiState = UIState.initial.obs;

  // ✅ Getter backward-compatible — Screen dùng controller.isLoading không cần đổi
  bool get isLoading => uiState.value == UIState.loading;

  void showLoading() => uiState.value = UIState.loading;
  
  void hideLoading() => uiState.value = UIState.success;

  void setEmpty() => uiState.value = UIState.empty;
  
  void setError() => uiState.value = UIState.error;
  
  void setOfflineCached() => uiState.value = UIState.offlineCached;
  
  void setInitial() => uiState.value = UIState.initial;

  void showSuccessMessage(String title, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.closeAllSnackbars();
      Get.snackbar(
        title,
        message,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    });
  }

  void showErrorMessage(String title, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.closeAllSnackbars();
      Get.snackbar(
        title,
        message,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    });
  }

  void showWarningMessage(String title, String message) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }
}
