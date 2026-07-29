import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/models/budget_category_group.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';

class CategoryDetailController extends BaseController with BudgetAware {
  final TransactionRepository _transactionRepo =
      Get.find<TransactionRepository>();
  final CategoryRepository _categoryRepo = Get.find<CategoryRepository>();
  final StorageService _storage = Get.find<StorageService>();

  late CategoryModel category;
  var isLoadingHistory = true.obs;
  var isCategoryDeleted = false.obs;

  // Danh sách các map chứa thông tin để hiển thị
  var historyList = <Map<String, dynamic>>[].obs;

  // --- Proxy Getters từ BudgetService (Tránh Get.find trong Screen) ---
  double get unallocatedAmount => budgetService.unallocatedAmount.value;
  List<BudgetCategoryGroup> get categoryGroups => budgetService.categoryGroups;

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

  /// Pull-to-Refresh: làm mới toàn bộ trang chi tiết danh mục
  Future<void> refreshAll() async {
    await Future.wait([fetchHistory(), budgetService.refreshData()]);
  }

  Future<void> fetchHistory() async {
    isLoadingHistory.value = true;

    final result = await ErrorHandler.execute(() async {
      final userId = _storage.read<String>(AppKeys.userId) ?? '';

      // 1. (REMOVED) Lấy toàn bộ ví để map tên

      // 2. Lấy top 5 giao dịch
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

      final rawHistory = await _transactionRepo.getHistoryByCategory(
        category.id,
        limit: 5,
        start: start,
        end: end,
      );

      // 3. Map lại thành danh sách dữ liệu hiển thị
      List<Map<String, dynamic>> displayList = [];
      for (var item in rawHistory) {
        final tx = item['transaction'];
        final detail = item['detail'];
        final walletName = 'Ngân sách';

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
      final now = budgetService.currentTrackingMonth.value;
      final monthYearStr =
          "${now.month.toString().padLeft(2, '0')}-${now.year}";

      await _categoryRepo.updateCategory(
        category.id,
        category.name,
        category.iconName,
        category.color,
        defaultBudget: newBudget,
      );
      final mbTarget = budgetService.getBudgetForCategory(category.id);
      if (mbTarget != null) {
        await _categoryRepo.updateMonthlyBudget(mbTarget.id, newBudget);
      } else {
        await _categoryRepo.createMonthlyBudget(
          categoryId: category.id,
          monthYear: monthYearStr,
          budgetedAmount: newBudget,
        );
      }

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
          final mbSource = budgetService.getBudgetForCategory(sourceCat.id);
          if (mbSource != null) {
            await _categoryRepo.updateMonthlyBudget(
              mbSource.id,
              sourceCategoryNewBudget,
            );
          } else {
            await _categoryRepo.createMonthlyBudget(
              categoryId: sourceCat.id,
              monthYear: monthYearStr,
              budgetedAmount: sourceCategoryNewBudget,
            );
          }
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

  Future<void> deleteCategory() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      await _categoryRepo.deleteCategory(category.id);
    }, tag: "DELETE_CATEGORY");
    hideLoading();

    await result.fold(
      (failure) async {
        showErrorMessage("Lỗi", "Không thể xóa danh mục: ${failure.message}");
      },
      (_) async {
        refreshBudget(); // Đồng bộ lại Service
        Get.back(result: true); // Quay lại trang trước và báo refresh
        showSuccessMessage("Thành công", "Đã xóa danh mục");
      },
    );
  }
}
