import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:appintern/domain/repositories/wallet_repository.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:flutter/material.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/services/budget_service.dart';

class CategoryDetailController extends BaseController with BudgetAware {
  final TransactionRepository _transactionRepo =
      Get.find<TransactionRepository>();
  final WalletRepository _walletRepo = Get.find<WalletRepository>();
  final CategoryRepository _categoryRepo = Get.find<CategoryRepository>();
  final StorageService _storage = Get.find<StorageService>();

  late CategoryModel category;
  var isLoadingHistory = true.obs;
  var isCategoryDeleted = false.obs;

  // Danh sách các map chứa thông tin để hiển thị
  var historyList = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    category = Get.arguments as CategoryModel;
    fetchHistory();

    // Lắng nghe sự thay đổi của transaction để cập nhật lại history nếu có thêm mới
    _transactionRepo.onTransactionUpdated.listen((_) {
      fetchHistory();
    });
  }

  Future<void> fetchHistory() async {
    isLoadingHistory.value = true;

    final result = await ErrorHandler.execute(() async {
      final userId = _storage.read<String>(AppKeys.userId) ?? '';

      // 1. Lấy toàn bộ ví để map tên
      final wallets = await _walletRepo.getWallets(userId);
      final walletMap = {for (var w in wallets) w.id: w.name};

      // 2. Lấy top 5 giao dịch
      final rawHistory = await _transactionRepo.getHistoryByCategory(
        category.id,
        limit: 5,
      );

      // 3. Map lại thành danh sách dữ liệu hiển thị
      List<Map<String, dynamic>> displayList = [];
      for (var item in rawHistory) {
        final tx = item['transaction'];
        final detail = item['detail'];
        final walletName = walletMap[tx.walletId] ?? 'Không rõ';

        displayList.add({
          'categoryName': category.name,
          'note': detail?.note ?? '',
          'walletName': walletName,
          'amount': tx.amount,
          'type': tx.type,
          'date': tx.transactionDate,
        });
      }
      return displayList;
    }, tag: 'FETCH_CATEGORY_HISTORY');

    result.fold(
      (failure) {
        showErrorMessage(
          'Lỗi',
          'Không thể tải lịch sử giao dịch: ${failure.message}',
        );
      },
      (data) {
        historyList.value = data;
      },
    );

    isLoadingHistory.value = false;
  }

  Future<void> updateCategory(String name, String icon) async {
    showLoading();

    final result = await ErrorHandler.execute(() async {
      await _categoryRepo.updateCategory(
        category.id,
        name,
        icon,
        category.color,
      );
    }, tag: "UPDATE_CATEGORY");

    hideLoading();
    result.fold((failure) => showErrorMessage('Lỗi', failure.message), (_) {
      category = CategoryModel(
        id: category.id,
        categoryTypeId: category.categoryTypeId,
        name: name,
        color: category.color,
        iconName: icon,
        defaultBudget: category.defaultBudget,
        spent: category.spent,
      );
      update();
      refreshBudget();
      showSuccessMessage('Thành công', 'Cập nhật danh mục thành công!');
    });
  }

  Future<void> updateBudget(
    double newBudget, {
    String? sourceCategoryId,
    double? sourceCategoryNewBudget,
  }) async {
    showLoading();

    final result = await ErrorHandler.execute(() async {
      await _categoryRepo.updateCategory(
        category.id,
        category.name,
        category.iconName,
        category.color,
        defaultBudget: newBudget,
      );

      // Cập nhật category nguồn (nếu có và không phải là 'unallocated')
      if (sourceCategoryId != null &&
          sourceCategoryId != 'unallocated' &&
          sourceCategoryNewBudget != null) {
        final sourceCatList = budgetService.categories
            .where((c) => c.categoryModel.id == sourceCategoryId)
            .toList();

        if (sourceCatList.isNotEmpty) {
          final sourceCat = sourceCatList.first.categoryModel;
          await _categoryRepo.updateCategory(
            sourceCat.id,
            sourceCat.name,
            sourceCat.iconName,
            sourceCat.color,
            defaultBudget: sourceCategoryNewBudget,
          );
        }
      }
    }, tag: "UPDATE_BUDGET");

    hideLoading();
    result.fold((failure) => showErrorMessage('Lỗi', failure.message), (_) {
      category = CategoryModel(
        id: category.id,
        categoryTypeId: category.categoryTypeId,
        name: category.name,
        color: category.color,
        iconName: category.iconName,
        defaultBudget: newBudget,
        spent: category.spent,
      );
      update();
      refreshBudget();
      showSuccessMessage('Thành công', 'Cập nhật số tiền phân bổ thành công!');
    });
  }

  void deleteCategory() {}
}
