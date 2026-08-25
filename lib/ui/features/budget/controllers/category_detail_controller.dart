import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/models/budget_category_group.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/transfer_log_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'dart:convert';
import 'package:appintern/ui/widgets/dialogs/confirm_dialog_widget.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appwrite/appwrite.dart';

class CategoryDetailController extends BaseController with BudgetAware {
  final TransactionRepository _transactionRepo =
      Get.find<TransactionRepository>();
  final CategoryRepository _categoryRepo = Get.find<CategoryRepository>();
  final StorageService _storage = Get.find<StorageService>();
  final TransferLogRepository _transferLogRepo =
      Get.find<TransferLogRepository>();

  late CategoryModel category;
  var isLoadingHistory = true.obs;
  var isLoadingTransferHistory = true.obs;
  var isCategoryDeleted = false.obs;

  // Danh sách các map chứa thông tin để hiển thị
  var historyList = <Map<String, dynamic>>[].obs;
  var transferHistoryList = <Map<String, dynamic>>[].obs;

  // --- Proxy Getters từ BudgetService (Tránh Get.find trong Screen) ---
  double get unallocatedAmount => budgetService.unallocatedAmount.value;
  List<BudgetCategoryGroup> get categoryGroups => budgetService.activeCategoryGroups;

  double get currentMonthBudget {
    return budgetService
            .getBudgetForCategory(category.id)
            ?.budgetedAmount ??
        category.defaultBudget;
  }

  @override
  void onInit() {
    super.onInit();
    category = Get.arguments as CategoryModel;

    // Lắng nghe sự thay đổi của danh mục từ BudgetService để cập nhật UI
    _updateCategoryFromBudgetService();
    ever(budgetService.categories, (_) => _updateCategoryFromBudgetService());

    fetchHistory();

    // Lắng nghe sự thay đổi của transaction để cập nhật lại history nếu có thêm mới
    _transactionRepo.onTransactionUpdated.listen((_) {
      fetchHistory();
    });
  }

  void _updateCategoryFromBudgetService() {
    final updatedCat = budgetService.categories.firstWhereOrNull(
      (c) => c.categoryModel.id == category.id,
    );
    if (updatedCat != null) {
      category = CategoryModel(
        id: updatedCat.categoryModel.id,
        categoryTypeId: updatedCat.categoryModel.categoryTypeId,
        name: updatedCat.name,
        color: updatedCat.categoryModel.color,
        iconName: updatedCat.icon,
        defaultBudget: updatedCat.allocated,
        isActive: updatedCat.categoryModel.isActive,
        spent: updatedCat.spent,
      );
      update(); // Cập nhật các UI dùng GetBuilder
    }
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

    // Lấy lịch sử cân bằng ngân sách
    isLoadingTransferHistory.value = true;
    final transferResult = await ErrorHandler.execute(() async {
      final transferLogs = await _transferLogRepo.getTransferLogsByCategoryId(
        category.id,
        limit: 5,
      );

      List<Map<String, dynamic>> tList = [];
      for (var log in transferLogs) {
        bool isOutbound = category.id == log.fromCategoryId;
        String partnerId = isOutbound ? log.toCategoryId : log.fromCategoryId;

        String partnerName = "Chưa phân bổ";
        String partnerIcon = "icon_wallet.png";
        String partnerColor = "#9E9E9E"; // Grey

        if (partnerId.isNotEmpty) {
          final pList = budgetService.categories
              .where((c) => c.categoryModel.id == partnerId)
              .toList();
          if (pList.isNotEmpty) {
            partnerName = pList.first.name;
            partnerIcon = pList.first.icon;
            partnerColor = pList.first.categoryModel.color;
          }
        }

        tList.add({
          'action': isOutbound ? 'Chuyển sang' : 'Nhận từ',
          'amount': isOutbound ? -log.amount : log.amount,
          'partnerName': partnerName,
          'partnerIcon': partnerIcon,
          'partnerColor': partnerColor,
          'date': log.createdAt,
          'note': log.note,
        });
      }
      return tList;
    }, tag: 'FETCH_TRANSFER_HISTORY');

    transferResult.fold(
      (failure) {
        // Có thể bỏ qua hoặc thông báo
      },
      (data) {
        transferHistoryList.value = data;
      },
    );

    isLoadingTransferHistory.value = false;
  }

  Future<void> updateCategory(String name, String icon) async {
    showLoading();
    final networkService = Get.find<NetworkService>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    final localDb = Get.find<LocalDatabaseService>();

    if (networkService.isOffline.value) {
      if (offlineSyncService.checkAndShowManualQueueFull()) {
        hideLoading();
        return;
      }
      final payload = jsonEncode({
        'id': category.id,
        'name': name.trim(),
        'iconName': icon,
        'color': category.color,
      });
      await offlineSyncService.queueManualTask('UPDATE_CATEGORY', payload);
      await localDb.updateCategory(
        category.id,
        name.trim(),
        icon,
        category.color,
      );

      category = CategoryModel(
        id: category.id,
        categoryTypeId: category.categoryTypeId,
        name: name.trim(),
        color: category.color,
        iconName: icon,
        defaultBudget: category.defaultBudget,
        spent: category.spent,
      );

      hideLoading();
      update();
      refreshBudget();
      showSuccessMessage(
        "Đã lưu (Ngoại tuyến)",
        "Dữ liệu sẽ được đồng bộ khi có mạng",
      );
    } else {
      final result = await ErrorHandler.execute(() async {
        await _categoryRepo.updateCategory(
          category.id,
          name.trim(),
          icon,
          category.color,
        );
      }, tag: "UPDATE_CATEGORY");

      hideLoading();
      result.fold((failure) => showErrorMessage('Lỗi', failure.message), (_) {
        category = CategoryModel(
          id: category.id,
          categoryTypeId: category.categoryTypeId,
          name: name.trim(),
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
  }

  Future<void> updateBudget(
    double newBudget, {
    String? sourceCategoryId,
    double? sourceCategoryNewBudget,
    String? note,
  }) async {
    showLoading();
    final networkService = Get.find<NetworkService>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    final localDb = Get.find<LocalDatabaseService>();
    final now = budgetService.currentTrackingMonth.value;
    final monthYearStr = "${now.month.toString().padLeft(2, '0')}-${now.year}";

    if (networkService.isOffline.value) {
      if (offlineSyncService.checkAndShowManualQueueFull()) {
        hideLoading();
        return;
      }
      final allocations = [
        {'categoryId': category.id, 'amount': newBudget},
        if (sourceCategoryId != null &&
            sourceCategoryId != 'unallocated' &&
            sourceCategoryNewBudget != null)
          {'categoryId': sourceCategoryId, 'amount': sourceCategoryNewBudget},
      ];

      // Amount transferred is difference between new target budget and old target budget
      double currentBudget =
          budgetService.getBudgetForCategory(category.id)?.budgetedAmount ??
          category.defaultBudget;
      double amountChange = newBudget - currentBudget;

      final transferLogs = <Map<String, dynamic>>[];
      if (amountChange > 0) {
        transferLogs.add({
          '\$id': ID.unique(),
          'amount': amountChange,
          'fromCategoryId':
              (sourceCategoryId == null || sourceCategoryId == 'unallocated')
              ? null
              : sourceCategoryId,
          'toCategoryId': category.id,
          'note': note ?? 'Cân bằng ngân sách',
        });
      } else if (amountChange < 0) {
        transferLogs.add({
          '\$id': ID.unique(),
          'amount': -amountChange,
          'fromCategoryId': category.id,
          'toCategoryId':
              (sourceCategoryId == null || sourceCategoryId == 'unallocated')
              ? null
              : sourceCategoryId,
          'note': note ?? 'Cân bằng ngân sách',
        });
      }

      final payload = jsonEncode({
        'monthYear': monthYearStr,
        'allocations': allocations,
        'transferLogs': transferLogs,
      });
      await offlineSyncService.queueManualTask('UPDATE_BUDGET', payload);

      if (amountChange > 0) {
        await localDb.transferBudgetLocal(
          (sourceCategoryId == null || sourceCategoryId == 'unallocated')
              ? null
              : sourceCategoryId,
          category.id,
          amountChange,
          monthYearStr,
        );
      } else if (amountChange < 0) {
        await localDb.transferBudgetLocal(
          category.id,
          (sourceCategoryId == null || sourceCategoryId == 'unallocated')
              ? null
              : sourceCategoryId,
          -amountChange,
          monthYearStr,
        );
      }

      showSuccessMessage(
        "Đã lưu (Ngoại tuyến)",
        "Dữ liệu sẽ được đồng bộ khi có mạng",
      );
      await budgetService.loadDataFromLocal(); // Refresh UI
    } else {
      final allocations = [
        {'categoryId': category.id, 'amount': newBudget},
        if (sourceCategoryId != null &&
            sourceCategoryId != 'unallocated' &&
            sourceCategoryNewBudget != null)
          {'categoryId': sourceCategoryId, 'amount': sourceCategoryNewBudget},
      ];

      final result = await ErrorHandler.execute(() async {
        double currentBudget =
            budgetService.getBudgetForCategory(category.id)?.budgetedAmount ??
            category.defaultBudget;
        double amountChange = newBudget - currentBudget;

        final transferLogs = <Map<String, dynamic>>[];
        if (amountChange > 0) {
          transferLogs.add({
            '\$id': ID.unique(),
            'amount': amountChange,
            'fromCategoryId':
                (sourceCategoryId == null || sourceCategoryId == 'unallocated')
                ? null
                : sourceCategoryId,
            'toCategoryId': category.id,
            'note': note ?? 'Cân bằng ngân sách',
          });
        } else if (amountChange < 0) {
          transferLogs.add({
            '\$id': ID.unique(),
            'amount': -amountChange,
            'fromCategoryId': category.id,
            'toCategoryId':
                (sourceCategoryId == null || sourceCategoryId == 'unallocated')
                ? null
                : sourceCategoryId,
            'note': note ?? 'Cân bằng ngân sách',
          });
        }

        await _categoryRepo.transferBudget(
          monthYearStr,
          allocations,
          transferLogs: transferLogs,
        );

        // Cập nhật LocalDB trực tiếp để UI phản hồi nhanh
        if (amountChange > 0) {
          await localDb.transferBudgetLocal(
            (sourceCategoryId == null || sourceCategoryId == 'unallocated')
                ? null
                : sourceCategoryId,
            category.id,
            amountChange,
            monthYearStr,
            isOffline: false,
          );
        } else if (amountChange < 0) {
          await localDb.transferBudgetLocal(
            category.id,
            (sourceCategoryId == null || sourceCategoryId == 'unallocated')
                ? null
                : sourceCategoryId,
            -amountChange,
            monthYearStr,
            isOffline: false,
          );
        }
      }, tag: "UPDATE_BUDGET");

      hideLoading();
      result.fold((failure) => showErrorMessage('Lỗi', failure.message), (_) async {
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
        await budgetService.loadDataFromLocal();
        showSuccessMessage(
          'Thành công',
          'Cập nhật số tiền phân bổ thành công!',
        );
      });
    }
  }

  bool get hasLinkedGoal {
    return budgetService.goals.any((g) => g.categoryId == category.id);
  }

  Future<void> deleteCategory() async {
    showLoading();
    final networkService = Get.find<NetworkService>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    final localDb = Get.find<LocalDatabaseService>();

    if (networkService.isOffline.value) {
      if (offlineSyncService.checkAndShowManualQueueFull()) {
        hideLoading();
        return;
      }
      final payload = jsonEncode({'id': category.id});
      await offlineSyncService.queueManualTask('DELETE_CATEGORY', payload);

      // Update local db
      await localDb.deleteCategory(category.id);

      hideLoading();
      refreshBudget(); // Đồng bộ lại Service
      Get.back(result: true); // Quay lại trang trước và báo refresh
      showSuccessMessage(
        "Đã lưu (Ngoại tuyến)",
        "Danh mục sẽ được xóa trên máy chủ khi có mạng",
      );
    } else {
      final result = await ErrorHandler.execute(() async {
        await _categoryRepo.deleteCategory(category.id);
        await localDb.deleteCategory(category.id);
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
}
