import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/models/wallet_model.dart';
import 'package:appintern/domain/repositories/wallet_repository.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/errors/error_handler.dart';

class WalletController extends BaseController {
  final WalletRepository walletRepository = Get.find<WalletRepository>();
  final storage = Get.find<StorageService>();

  var wallets = <WalletModel>[].obs;
  var isLoadingWallets = false.obs;

  final nameController = TextEditingController();
  final balanceController = TextEditingController();

  final RxString selectedIcon = '📦'.obs;
  final RxBool isDefault = false.obs;

  @override
  void onReady() {
    super.onReady();
    fetchWallets();
  }

  @override
  void onClose() {
    nameController.dispose();
    balanceController.dispose();
    super.onClose();
  }

  void onSumbitCreateWallet() {
    final name = nameController.text.trim();

    final rawBalanceString = balanceController.text.replaceAll('.', '');
    final balance = double.tryParse(rawBalanceString) ?? 0.0;

    if (name.isEmpty) {
      showErrorMessage('Lỗi', 'Vui lòng nhập tên tài khoản');
      return;
    }

    // Mặc định currency là VND theo design
    createWallet(name, balance, 'VND', selectedIcon.value, isDefault.value);
  }

  Future<void> fetchWallets() async {
    final userId = storage.read(AppKeys.userId) ?? "";
    if (userId.isEmpty) return;

    showLoading();
    final result = await ErrorHandler.execute(() async {
      final fetchedWallets = await walletRepository.getWallets(userId);
      wallets.value = fetchedWallets;
    }, tag: "FETCH_WALLETS");
    hideLoading();

    result.fold((failure) {
      showErrorMessage("Lỗi", "Không thể tải danh sách ví: ${failure.message}");
    }, (_) {});
  }

  Future<void> createWallet(
    String name,
    double initialBalance,
    String currency,
    String iconName,
    bool isDefaultFlag,
  ) async {
    final userId = storage.read(AppKeys.userId) ?? "";
    if (userId.isEmpty) {
      showErrorMessage('Lỗi', 'Không tìm thấy thông tin người dùng');
      return;
    }

    showLoading();
    final result = await ErrorHandler.execute(() async {
      final newWallet = await walletRepository.createWallet(
        userId,
        name,
        initialBalance,
        currency,
        iconName,
        isDefaultFlag,
      );
      wallets.add(newWallet);
    }, tag: "CREATE_WALLET");
    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Lỗi", "Không thể tạo ví: ${failure.message}");
      },
      (_) {
        Get.back();
        // Khi Back thanh cong thi fetch lai Data
        showSuccessMessage('Thành công', 'Đã thêm ví mới');
      },
    );
  }

  Future<void> deleteWallet(String walletId) async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      await walletRepository.deleteWallet(walletId);
      wallets.removeWhere((w) => w.id == walletId);
    }, tag: "DELETE_WALLET");
    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Lỗi", "Không thể xóa ví: ${failure.message}");
      },
      (_) {
        showSuccessMessage('Thành công', 'Đã xóa ví');
      },
    );
  }
}
