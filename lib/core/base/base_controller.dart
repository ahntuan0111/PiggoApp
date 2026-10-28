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
    final safeMessage = _sanitizeForUser(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.closeAllSnackbars();
      Get.snackbar(
        title,
        safeMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    });
  }

  void showWarningMessage(String title, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.closeAllSnackbars();
      Get.snackbar(
        title,
        message,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    });
  }

  void showInfoMessage(String title, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.closeAllSnackbars();
      Get.snackbar(
        title,
        message,
        backgroundColor: Colors.blueAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    });
  }

  /// Safety net cuối cùng: lọc message kỹ thuật trước khi hiển thị lên UI.
  /// Nếu message chứa bất kỳ pattern kỹ thuật nào → thay bằng fallback generic.
  static String _sanitizeForUser(String message) {
    // Danh sách các pattern kỹ thuật không bao giờ nên hiện cho End User
    final technicalPatterns = [
      RegExp(r'[a-f0-9]{20,}'),                       // Database ID (hex string dài 20+ ký tự)
      RegExp(r'[A-Z][a-z]+Exception'),                 // CamelCase exceptions (AppwriteException, ServerException...)
      RegExp(r"type '.+' is not a subtype"),            // Dart type errors
      RegExp(r'Document with'),                         // Appwrite document errors
      RegExp(r'Collection|Index', caseSensitive: false), // DB structure terms (trừ "Database" vì có thể dùng trong tiếng Việt)
      RegExp(r'\.dart[:.]'),                            // Dart file references
      RegExp(r'Stack\s?Trace|Traceback'),               // Stack traces
      RegExp(r'#\d+\s+'),                               // Stack trace line numbers (#0, #1...)
      RegExp(r'null|undefined', caseSensitive: false),   // Null/undefined references
      RegExp(r'\b\d{3}\b\s'),                           // Standalone HTTP status codes (404 , 500 ...)
    ];

    for (var pattern in technicalPatterns) {
      if (pattern.hasMatch(message)) {
        return 'Đã xảy ra lỗi, vui lòng thử lại sau.';
      }
    }
    return message;
  }
}
