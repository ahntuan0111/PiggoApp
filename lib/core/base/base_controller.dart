import 'package:flutter/material.dart';
import 'package:get/get.dart';

abstract class BaseController extends GetxController {
  var isLoading = false.obs;

  void showLoading() {
    isLoading.value = true;
  }

  void hideLoading() {
    isLoading.value = false;
  }

  void showSuccessMessage(String title, String message) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  void showErrorMessage(String title, String message) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      backgroundColor: Colors.redAccent.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
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
