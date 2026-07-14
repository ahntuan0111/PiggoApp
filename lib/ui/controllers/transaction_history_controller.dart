import 'dart:async';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/wallet_model.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TransactionHistoryController extends BaseController with BudgetAware {
  final TransactionRepository _transactionRepo = Get.find<TransactionRepository>();

  // Filter States
  final selectedMonth = DateTime.now().obs;
  final sortAscending = false.obs; // false = Mới nhất (Giảm dần), true = Cũ nhất (Tăng dần)
  final selectedWallet = Rxn<WalletModel>();
  final selectedCategory = Rxn<CategoryModel>();
  final selectedType = Rxn<String>(); // 'EXPENSE' or 'INCOME'

  // Search State
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  Timer? _debounce;

  // Data States
  final transactionsList = <Map<String, dynamic>>[].obs;
  
  // Pagination States
  final isFetchingMore = false.obs;
  final hasReachedMax = false.obs;
  static const int pageSize = 20;

  @override
  void onInit() {
    super.onInit();
    
    // Lắng nghe sự thay đổi của text search để thực hiện Debounce 500ms
    searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (searchQuery.value != searchController.text) {
          searchQuery.value = searchController.text;
          _refreshData();
        }
      });
    });

    // Lắng nghe thay đổi các bộ lọc khác
    ever(selectedMonth, (_) => _refreshData());
    ever(sortAscending, (_) => _refreshData());
    ever(selectedWallet, (_) => _refreshData());
    ever(selectedCategory, (_) => _refreshData());
    ever(selectedType, (_) => _refreshData());
  }

  @override
  void onReady() {
    super.onReady();
    _refreshData();
  }

  void _refreshData() {
    // Reset phân trang và tải lại từ đầu
    hasReachedMax.value = false;
    transactionsList.clear();
    fetchTransactions(isRefresh: true);
  }

  Future<void> fetchTransactions({bool isRefresh = false}) async {
    if (hasReachedMax.value) return;

    if (isRefresh) {
      showLoading();
    } else {
      isFetchingMore.value = true;
    }

    final result = await ErrorHandler.execute(() async {
      List<String> walletIds = [];
      if (selectedWallet.value != null) {
        walletIds.add(selectedWallet.value!.id);
      } else {
        walletIds = budgetService.wallets.map((w) => w.id).toList();
      }

      if (walletIds.isEmpty) return <Map<String, dynamic>>[];

      // Tính start/end cho selectedMonth
      final start = DateTime(selectedMonth.value.year, selectedMonth.value.month, 1);
      final end = DateTime(selectedMonth.value.year, selectedMonth.value.month + 1, 0, 23, 59, 59);

      String? lastDocId;
      if (!isRefresh && transactionsList.isNotEmpty) {
        lastDocId = transactionsList.last['transaction'].id;
      }

      return await _transactionRepo.getTransactionsByWalletsAndFilters(
        walletIds: walletIds,
        start: start,
        end: end,
        categoryId: selectedCategory.value?.id,
        type: selectedType.value,
        searchQuery: searchQuery.value,
        limit: pageSize,
        cursorAfter: lastDocId,
        ascending: sortAscending.value,
      );
    }, tag: "FETCH_TRANSACTION_HISTORY");

    if (isRefresh) hideLoading();
    isFetchingMore.value = false;

    result.fold(
      (failure) {
        showErrorMessage('Lỗi', 'Không thể tải lịch sử giao dịch: ${failure.message}');
      },
      (data) {
        if (data.isEmpty || data.length < pageSize) {
          hasReachedMax.value = true;
        }
        if (isRefresh) {
          transactionsList.assignAll(data);
        } else {
          transactionsList.addAll(data);
        }
      },
    );
  }

  // Cung cấp dữ liệu đã được group theo ngày cho View
  Map<String, List<Map<String, dynamic>>> get groupedTransactions {
    final map = <String, List<Map<String, dynamic>>>{};
    for (var item in transactionsList) {
      final tx = item['transaction'];
      final dateKey = "${tx.transactionDate.day.toString().padLeft(2, '0')}/${tx.transactionDate.month.toString().padLeft(2, '0')}/${tx.transactionDate.year}";
      
      if (!map.containsKey(dateKey)) {
        map[dateKey] = [];
      }
      
      // Bổ sung các trường UI hiển thị
      final detail = item['detail'];
      final walletName = budgetService.wallets.firstWhereOrNull((w) => w.id == tx.walletId)?.name ?? 'Ví';
      final category = budgetService.categories.firstWhereOrNull((c) => c.categoryModel.id == tx.categoryId);
      
      map[dateKey]!.add({
        'transaction': tx,
        'detail': detail,
        'walletName': walletName,
        'categoryName': category?.name ?? 'Giao dịch',
        'icon': category?.icon ?? 'category',
      });
    }
    return map;
  }

  // --- Helpers UI Updates ---

  void pickMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth.value,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEBC14F), // Màu vàng cam chủ đạo
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      selectedMonth.value = DateTime(picked.year, picked.month, 1);
    }
  }

  void toggleSortOrder() {
    sortAscending.value = !sortAscending.value;
  }

  void clearFilters() {
    selectedWallet.value = null;
    selectedCategory.value = null;
    selectedType.value = null;
    searchController.clear();
    searchQuery.value = '';
    selectedMonth.value = DateTime.now();
    sortAscending.value = false;
  }

  @override
  void onClose() {
    searchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }
}
