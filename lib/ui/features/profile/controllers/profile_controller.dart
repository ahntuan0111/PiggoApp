import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appintern/core/utils/logger.dart';
import 'package:get/get.dart';
import 'package:appintern/data/models/user_profile_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/data/repositories/auth_repository.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/core/services/settings_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/services/notification_service.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';

class ProfileController extends BaseController {
  final AuthRepository authRepository = Get.find<AuthRepository>();
  final StorageService storageService = Get.find<StorageService>();
  final CategoryRepository categoryRepo = Get.find<CategoryRepository>();
  final SettingsService settingsService = Get.find<SettingsService>();

  final Rx<UserProfileModel?> currentUser = Rx<UserProfileModel?>(null);
  final Rx<Uint8List?> avatarBytes = Rx<Uint8List?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchUser();
  }

  Future<void> fetchUser() async {
    final result = await ErrorHandler.execute(() async {
      return await authRepository.getUser();
    }, tag: 'FETCH_USER');

    result.fold(
      (failure) => AppLogger.error(
        'PROFILE',
        'Failed to fetch user: ${failure.message}',
      ),
      (user) {
        currentUser.value = user;
        if (user != null && user.avatarPath != null && user.avatarPath!.isNotEmpty) {
          final file = File(user.avatarPath!);
          if (file.existsSync()) {
            avatarBytes.value = file.readAsBytesSync();
          }
        }
      },
    );
  }

  Future<void> changeAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      avatarBytes.value = bytes;

      final user = currentUser.value;
      if (user != null) {
        try {
          final storageRepo = Get.find<StorageRepository>();
          final localDb = Get.find<LocalDatabaseService>();
          final savedPath = await storageRepo.saveAvatarImage(File(image.path), user.id);
          final updatedUser = user.copyWith(avatarPath: savedPath);
          await localDb.saveUserProfile(updatedUser);
          currentUser.value = updatedUser;
          storageService.write(AppKeys.avatarUrl, savedPath);
        } catch (e) {
          AppLogger.error('PROFILE', 'Failed to save avatar image: $e');
        }
      }
      showSuccessMessage('Thành công', 'Đã cập nhật ảnh đại diện.');
    }
  }

  Future<void> forceSync() async {
    showLoading();
    try {
      final budgetService = Get.find<BudgetService>();
      await budgetService.refreshData();
      showSuccessMessage('Làm mới', 'Dữ liệu đã được cập nhật thành công.');
    } catch (e) {
      showErrorMessage('Lỗi', 'Không thể cập nhật dữ liệu: ${e.toString()}');
    } finally {
      hideLoading();
    }
  }

  void changeThemeMode(String mode) {
    settingsService.saveTheme(mode);
  }

  Future<void> toggleDailyReminder(bool value) async {
    if (value) {
      final notifService = Get.find<NotificationService>();
      final granted = await notifService.requestPermissions();
      if (!granted) {
        showWarningMessage(
          'Quyền thông báo',
          'Bạn cần cấp quyền để nhận nhắc nhở.',
        );
        return;
      }
    }
    settingsService.saveNotificationSettings(
      value,
      settingsService.reminderTime.value,
    );
  }

  Future<void> changeReminderTime(BuildContext context) async {
    final parts = settingsService.reminderTime.value.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final timeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      settingsService.saveNotificationSettings(
        settingsService.isDailyReminderEnabled.value,
        timeStr,
      );
    }
  }

  Future<void> deleteAccount() async {
    showLoading();
    final user = currentUser.value;
    final userId = user?.id ?? storageService.read<String>(AppKeys.userId);

    final result = await ErrorHandler.execute(() async {
      if (userId != null && userId.isNotEmpty) {
        await authRepository.deleteUserAccount(userId);
      } else {
        await authRepository.clearAllUserData();
      }
    }, tag: 'DELETE_ACCOUNT');
    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage('Lỗi xoá tài khoản', failure.message);
      },
      (data) {
        storageService.clearAll();
        Get.offAllNamed(Routes.ONBOARDING);
        showSuccessMessage('Thành công', 'Tài khoản và dữ liệu đã được xoá.');
      },
    );
  }

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
        Get.offAllNamed(Routes.ONBOARDING);
      },
    );
  }

  Future<void> resetAllData() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      await authRepository.clearAllUserData();
      await authRepository.logout();
      await Get.find<LocalDatabaseService>().clearAllData();
    }, tag: 'RESET_ALL_DATA');
    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage('Lỗi reset dữ liệu', failure.message);
      },
      (data) {
        storageService.clearAll();
        Get.offAllNamed(Routes.ONBOARDING);
        showSuccessMessage(
          'Thành công',
          'Đã xóa sạch dữ liệu. Vui lòng đăng nhập lại để bắt đầu từ đầu.',
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
      await Get.find<LocalDatabaseService>().clearAllData();

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

        showSuccessMessage(
          'Thành công',
          'Đã reset toàn bộ dữ liệu về trạng thái ban đầu.',
        );

        // Điều hướng về Home (Main) để kích hoạt giao diện trống
        Get.offAllNamed(Routes.MAIN);
      },
    );
  }
}
