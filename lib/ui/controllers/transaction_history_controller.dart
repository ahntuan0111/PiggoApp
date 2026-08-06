import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';

class TransactionHistoryController extends BaseController with BudgetAware {
  final TransactionRepository _transactionRepo =
      Get.find<TransactionRepository>();

  // Filter States
  final selectedMonth = DateTime.now().obs;
  final sortAscending =
      false.obs; // false = Mới nhất (Giảm dần), true = Cũ nhất (Tăng dần)
  final selectedCategory = Rxn<CategoryModel>();
  final selectedType = Rxn<String>(); // 'EXPENSE' or 'INCOME'

  // Search State
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  Timer? _debounce;

  // Data States
  List<Map<String, dynamic>> transactionsList = [];

  // Pagination States
  final isFetchingMore = false.obs;
  final hasReachedMax = false.obs;
  static const int pageSize = 20;

  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();

    scrollController.addListener(_onScroll);

    // Đọc arguments nếu có truyền từ màn hình khác
    if (Get.arguments != null) {
      if (Get.arguments is Map) {
        if (Get.arguments['category'] != null) {
          selectedCategory.value = Get.arguments['category'];
        }
      }
    }

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

    ever(selectedMonth, (_) => _refreshData());
    ever(sortAscending, (_) => _refreshData());
    ever(selectedCategory, (_) => _refreshData());
    ever(selectedType, (_) => _refreshData());

    // Lắng nghe BudgetService để nạp lại dữ liệu khi ví đã được load xong
    ever(budgetService.isDataLoaded, (loaded) {
      if (loaded) {
        _refreshData();
      }
    });
  }

  @override
  void onReady() {
    super.onReady();
    if (budgetService.isDataLoaded.value) {
      _refreshData();
    }
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
    update(['tx_list']);

    final result = await ErrorHandler.execute(() async {
      // Tính start/end cho selectedMonth
      final start = DateTime(
        selectedMonth.value.year,
        selectedMonth.value.month,
        1,
      );
      final end = DateTime(
        selectedMonth.value.year,
        selectedMonth.value.month + 1,
        0,
        23,
        59,
        59,
      );

      String? lastDocId;
      if (!isRefresh && transactionsList.isNotEmpty) {
        lastDocId = transactionsList.last['transaction'].id;
      }

      return await _transactionRepo.getTransactionsByFilters(
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

    await result.fold(
      (failure) async {
        showErrorMessage(
          'Lỗi',
          'Không thể tải lịch sử giao dịch: ${failure.message}',
        );
      },
      (data) async {
        if (data.isEmpty || data.length < pageSize) {
          hasReachedMax.value = true;
        }

        if (isRefresh) {
          transactionsList.clear();
        }
        transactionsList.addAll(data);
        update(['tx_list']);
      },
    );
  }

  // Cung cấp dữ liệu đã được group theo ngày cho View
  Map<String, List<Map<String, dynamic>>> get groupedTransactions {
    final map = <String, List<Map<String, dynamic>>>{};
    for (var item in transactionsList) {
      final tx = item['transaction'];
      final dateKey =
          "${tx.transactionDate.day.toString().padLeft(2, '0')}/${tx.transactionDate.month.toString().padLeft(2, '0')}/${tx.transactionDate.year}";

      if (!map.containsKey(dateKey)) {
        map[dateKey] = [];
      }

      // Bổ sung các trường UI hiển thị
      final detail = item['detail'];
      final walletName = 'Ngân sách';
      final category = budgetService.categories.firstWhereOrNull(
        (c) => c.categoryModel.id == tx.categoryId,
      );

      map[dateKey]!.add({
        'transaction': tx,
        'detail': detail,
        'walletName': walletName,
        'categoryName': category?.name ?? 'Giao dịch',
        'icon': category?.icon ?? 'icon_wallet.png',
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
    selectedCategory.value = null;
    selectedType.value = null;
    searchController.clear();
    searchQuery.value = '';
    selectedMonth.value = DateTime.now();
    sortAscending.value = false;
  }

  void _onScroll() {
    if (scrollController.hasClients) {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        if (!isFetchingMore.value && !hasReachedMax.value) {
          fetchTransactions(isRefresh: false);
        }
      }
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    searchController.dispose();
    _debounce?.cancel();
    super.onClose();
  }
}
