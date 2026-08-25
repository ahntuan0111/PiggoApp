import 'package:appintern/core/errors/exceptions.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Mixin xử lý lỗi Appwrite ở tầng Repository.
/// Tự động phát hiện và xử lý:
/// - 401 (Session hết hạn) → Đăng xuất + redirect Onboarding
/// - SocketException → NetworkException
/// - Các lỗi khác → ServerException
mixin AppwriteErrorHandler {
  // Flag chống gọi redirect nhiều lần khi có nhiều request cùng fail 401
  static bool _isHandlingSessionExpiry = false;

  Future<T> handleAppwriteError<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        _handleSessionExpired();
        throw ServerException(
          "Phiên đăng nhập hết hạn, vui lòng đăng nhập lại.",
          401,
          e.type,
        );
      }

      if (e.message != null &&
          (e.message!.contains('SocketException') ||
              e.message!.contains('Network is unreachable'))) {
        throw NetworkException("Không có kết nối mạng, vui lòng kiểm tra lại.");
      }
      // Bắt các lỗi của hệ thống Appwrite và ném lại thành lỗi nghiệp vụ của ứng dụng
      throw ServerException(e.message ?? "Lỗi máy chủ", e.code, e.type);
    } catch (e) {
      // Không re-catch lỗi đã được chuyển đổi
      if (e is ServerException || e is NetworkException) rethrow;

      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable')) {
        throw NetworkException("Không có kết nối mạng, vui lòng kiểm tra lại.");
      }
      throw ServerException("Đã xảy ra lỗi, vui lòng thử lại sau.");
    }
  }

  /// Xử lý session hết hạn: xóa dữ liệu cục bộ, redirect về Onboarding.
  /// Chỉ chạy khi ở UI Isolate (có StorageService đã đăng ký).
  void _handleSessionExpired() {
    // Không xử lý trong Background Isolate
    if (!Get.isRegistered<StorageService>()) return;
    // Chống gọi trùng
    if (_isHandlingSessionExpiry) return;
    _isHandlingSessionExpiry = true;

    try {
      final storage = Get.find<StorageService>();
      storage.clearAll();

      // Sử dụng addPostFrameCallback để đảm bảo navigation an toàn
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(Routes.ONBOARDING);
        Get.closeAllSnackbars();
        Get.snackbar(
          "Phiên đăng nhập hết hạn",
          "Vui lòng đăng nhập lại.",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      });
    } finally {
      // Reset flag sau 2s để cho phép xử lý lại nếu cần
      Future.delayed(const Duration(seconds: 2), () {
        _isHandlingSessionExpiry = false;
      });
    }
  }
}
