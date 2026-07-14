import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/models/wallet_model.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/domain/repositories/wallet_repository.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/errors/error_handler.dart';

class WalletController extends BaseController with BudgetAware {
  final WalletRepository walletRepository = Get.find<WalletRepository>();
  final TransactionRepository transactionRepository =
      Get.find<TransactionRepository>();
  final storage = Get.find<StorageService>();

  late final RxList<WalletModel> wallets = budgetService.wallets.toList().obs;
  var recentTransactions = <Map<String, dynamic>>[].obs;
  var isLoadingWallets = false.obs;

  final nameController = TextEditingController();
  final balanceController = TextEditingController();
  final noteController = TextEditingController();

  bool get isAdjustMode => wallets.isNotEmpty;
  var isAdding = true.obs;

  final RxString selectedIcon = '📦'.obs;
  final RxBool isDefault = false.obs;

  @override
  void onReady() {
    super.onReady();
    fetchWallets().then((_) => fetchRecentTransactions());

    // Lắng nghe sự thay đổi của giao dịch
    transactionRepository.onTransactionUpdated.listen((_) {
      fetchWallets().then((_) => fetchRecentTransactions());
      budgetService.refreshData();
    });
  }

  @override
  void onClose() {
    nameController.dispose();
    balanceController.dispose();
    noteController.dispose();
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

  Future<void> fetchRecentTransactions() async {
    if (wallets.isEmpty) {
      recentTransactions.clear();
      return;
    }

    final walletIds = wallets.map((w) => w.id).toList();

    final result = await ErrorHandler.execute(() async {
      final history = await transactionRepository.getHistoryByWallets(
        walletIds,
        limit: 15,
      );
      recentTransactions.value = history;
    }, tag: "FETCH_GLOBAL_HISTORY");

    result.fold((failure) {
      print("Không thể tải lịch sử giao dịch: ${failure.message}");
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

  Future<void> adjustBudget() async {
    final rawAmount = balanceController.text.replaceAll('.', '');
    final amount = double.tryParse(rawAmount) ?? 0.0;
    
    if (amount <= 0) {
      showErrorMessage('Lỗi', 'Vui lòng nhập số tiền hợp lệ');
      return;
    }

    final userId = storage.read(AppKeys.userId) ?? "";
    if (userId.isEmpty || wallets.isEmpty) return;

    final targetWallet = wallets.first; // Lấy ví đầu tiên / mặc định
    final note = noteController.text.trim();
    final description = note.isEmpty 
      ? (isAdding.value ? 'Bổ sung ngân sách' : 'Điều chỉnh giảm ngân sách')
      : note;

    showLoading();
    final result = await ErrorHandler.execute(() async {
      final transaction = TransactionModel(
        id: '',
        walletId: targetWallet.id,
        categoryId: '', // Bỏ trống category vì đây là khoản unallocated
        amount: amount,
        type: isAdding.value ? 'INCOME' : 'EXPENSE',
        transactionDate: DateTime.now(),
        status: 'COMPLETED',
      );

      final transactionDetail = TransactionDetailModel(
        id: '',
        transactionId: '',
        note: description,
        receiptFileIds: const [],
        rawInputText: '',
        confidenceScore: 0.0,
      );

      await transactionRepository.createWalletAdjustmentTransaction(
        transaction: transaction,
        transactionDetail: transactionDetail,
        currentWallet: targetWallet,
      );
      
    }, tag: "ADJUST_BUDGET");
    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Lỗi", "Không thể điều chỉnh ngân sách: ${failure.message}");
      },
      (_) {
        Get.back();
        showSuccessMessage('Thành công', 'Đã cập nhật ngân sách');
        // Không cần fetchData ở đây vì _transactionUpdatedController 
        // sẽ báo cho HomeController refreshData tự động
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
