import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/utils/logger.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:intl/intl.dart';

class WalletController extends BaseController with BudgetAware {
  final TransactionRepository transactionRepository =
      Get.find<TransactionRepository>();
  final storage = Get.find<StorageService>();

  var recentTransactions = <Map<String, dynamic>>[].obs;
  var isLoadingWallets = false.obs;

  final nameController = TextEditingController();
  final balanceController = TextEditingController();
  final noteController = TextEditingController();

  final isAdjustMode = false.obs;
  var isAdding = true.obs;

  // Edit Mode cho Transaction
  var isEditTransactionMode = false.obs;
  TransactionModel? editingTransaction;
  TransactionDetailModel? editingDetail;

  final RxString selectedIcon = '📦'.obs;
  final RxBool isDefault = false.obs;
  var inputAmount = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    balanceController.addListener(_onBalanceChanged);

    if (Get.arguments != null) {
      if (Get.arguments['isAdjustMode'] == true) {
        isAdjustMode.value = true;
      }

      if (Get.arguments['isEdit'] == true) {
        isEditTransactionMode.value = true;
        isAdjustMode.value = true;
        editingTransaction = Get.arguments['transaction'] as TransactionModel?;
        editingDetail = Get.arguments['detail'] as TransactionDetailModel?;

        if (editingTransaction != null) {
          final formatter = NumberFormat('#,###', 'vi_VN');
          balanceController.text = formatter.format(editingTransaction!.amount);
          noteController.text =
              editingDetail?.note ?? editingTransaction!.note ?? '';
          isAdding.value = editingTransaction!.type == 'INCOME';
        }
      }
    }
  }

  void _onBalanceChanged() {
    final raw = balanceController.text
        .replaceAll('.', '')
        .replaceAll('đ', '')
        .trim();
    inputAmount.value = double.tryParse(raw) ?? 0.0;
  }

  double get currentTotalBalance => budgetService.totalWalletBalance.value;

  double get newTotalBalance {
    if (isAdding.value) {
      return currentTotalBalance + inputAmount.value;
    } else {
      return currentTotalBalance - inputAmount.value;
    }
  }

  void onReady() {
    super.onReady();
    fetchRecentTransactions();

    // Lắng nghe sự thay đổi của giao dịch
    transactionRepository.onTransactionUpdated.listen((_) {
      fetchRecentTransactions();
      budgetService.refreshData();
    });
  }

  void resetFields() {
    nameController.clear();
    balanceController.clear();
    noteController.clear();
    inputAmount.value = 0.0;
    isAdding.value = true;
    isEditTransactionMode.value = false;
    editingTransaction = null;
    editingDetail = null;
  }

  @override
  void onClose() {
    balanceController.removeListener(_onBalanceChanged);
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
    // Không còn wallet
  }

  Future<void> fetchRecentTransactions() async {
    final result = await ErrorHandler.execute(() async {
      final currentMonth = budgetService.currentTrackingMonth.value;
      final start = DateTime(currentMonth.year, currentMonth.month, 1);
      final end = DateTime(
        currentMonth.year,
        currentMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      final history = await transactionRepository.getRecentHistory(
        limit: 15,
        start: start,
        end: end,
      );
      recentTransactions.value = history;
    }, tag: "FETCH_GLOBAL_HISTORY");

    result.fold((failure) {
      AppLogger.error("FETCH_GLOBAL_HISTORY", failure.message);
    }, (_) {});
  }

  Future<void> createWallet(
    String name,
    double initialBalance,
    String currency,
    String iconName,
    bool isDefaultFlag,
  ) async {
    showErrorMessage('Tính năng', 'Tính năng đã bị vô hiệu hóa.');
  }

  Future<void> adjustBudget() async {
    final rawAmount = balanceController.text.replaceAll('.', '');
    final amount = double.tryParse(rawAmount) ?? 0.0;

    if (amount <= 0) {
      showErrorMessage('Lỗi', 'Vui lòng nhập số tiền hợp lệ');
      return;
    }

    final userId = storage.read(AppKeys.userId) ?? "";
    if (userId.isEmpty) return;
    final note = noteController.text.trim();
    final description = note.isEmpty
        ? (isAdding.value ? 'Bổ sung ngân sách' : 'Điều chỉnh giảm ngân sách')
        : note;

    showLoading();
    final result = await ErrorHandler.execute(() async {
      if (isEditTransactionMode.value && editingTransaction != null) {
        final newTx = TransactionModel(
          id: editingTransaction!.id,
          categoryId: '',
          amount: amount,
          type: isAdding.value ? 'INCOME' : 'EXPENSE',
          transactionDate: editingTransaction!.transactionDate,
          status: editingTransaction!.status,
          note: description,
        );

        final newDetail = TransactionDetailModel(
          id: editingDetail?.id ?? '',
          transactionId: editingTransaction!.id,
          note: description,
          receiptFileIds: editingDetail?.receiptFileIds ?? const [],
          rawInputText: editingDetail?.rawInputText ?? '',
          confidenceScore: editingDetail?.confidenceScore ?? 0.0,
        );

        await transactionRepository.updateWalletAdjustmentTransaction(
          oldTransaction: editingTransaction!,
          newTransaction: newTx,
          newTransactionDetail: newDetail,
        );
      } else {
        final transaction = TransactionModel(
          id: '',
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
        );
      }
    }, tag: "ADJUST_BUDGET");
    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage(
          "Lỗi",
          "Không thể điều chỉnh ngân sách: ${failure.message}",
        );
      },
      (_) {
        // Không cần fetchData ở đây vì _transactionUpdatedController
        // sẽ báo cho HomeController refreshData tự động
        Get.back(result: true);
        // Snackbar do màn hình Caller hiển thị (Caller Pattern)
      },
    );
  }

  Future<void> deleteWallet(String walletId) async {
    showErrorMessage('Tính năng', 'Tính năng đã bị vô hiệu hóa.');
  }
}
