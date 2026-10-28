import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';

class BudgetDistributionGroup {
  final String typeId;
  final String typeName;
  final List<CategoryModel> categories;
  final RxDouble totalAllocated = 0.0.obs;

  BudgetDistributionGroup(this.typeId, this.typeName, this.categories);
}

class BudgetDistributionController extends BaseController {
  final storage = Get.find<StorageService>();
  final CategoryRepository categoryRepository = Get.find<CategoryRepository>();

  var currentUserId = "".obs;

  // Tong quy
  final totalWalletBalance = 0.0.obs;

  // Tien đã được phân bố
  final allocatedAmount = 0.0.obs;

  // Tiền chưa phân bố
  final unallocatedAmount = 0.0.obs;

  final categoryGroups = <BudgetDistributionGroup>[].obs;

  // Bản đồ lưu trữ TextEditingController cho mỗi categoryId
  final textControllers = <String, TextEditingController>{};

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = storage.read(AppKeys.userId) ?? "";
  }

  @override
  void onReady() {
    super.onReady();
    fetchData();
  }

  void fetchData() {
    final userId = currentUserId.value;
    if (userId.isEmpty) return;

    final budgetService = Get.find<BudgetService>();
    totalWalletBalance.value = budgetService.totalWalletBalance.value;

    if (budgetService.categoryGroups.isEmpty) {
      categoryGroups.clear();
      return;
    }

    final distributionGroups = <BudgetDistributionGroup>[];

    for (var budgetGroup in budgetService.activeCategoryGroups) {
      List<CategoryModel> categoriesInGroup = [];
      for (var budgetCat in budgetGroup.categories) {
        if (budgetCat.categoryModel.isActive) {
          categoriesInGroup.add(budgetCat.categoryModel);

          final mb = budgetService.getBudgetForCategory(
            budgetCat.categoryModel.id,
          );
          double remaining = mb != null
              ? (mb.budgetedAmount + mb.rolloverAmount) - mb.spentAmount
              : budgetCat.categoryModel.remaining;

          String currentAmount = formatCurrency(remaining).trim();

          if (!textControllers.containsKey(budgetCat.categoryModel.id)) {
            final newController = TextEditingController(text: currentAmount);
            newController.addListener(_calculateTotals);
            textControllers[budgetCat.categoryModel.id] = newController;
          } else {
            textControllers[budgetCat.categoryModel.id]!.text = currentAmount;
          }
        }
      }

      if (categoriesInGroup.isNotEmpty) {
        distributionGroups.add(
          BudgetDistributionGroup(
            budgetGroup.typeId,
            budgetGroup.typeName,
            categoriesInGroup,
          ),
        );
      }
    }

    categoryGroups.value = distributionGroups;
    _calculateTotals();
  }

  void _calculateTotals() {
    double currentRemainingBudgets = 0.0;

    // Tính tổng số tiền đang hiển thị trên các TextField

    for (var group in categoryGroups) {
      double groupAllocated = 0.0;
      for (var cat in group.categories) {
        final controller = textControllers[cat.id];
        if (controller != null) {
          String text = controller.text
              .replaceAll('.', '')
              .replaceAll(',', '')
              .replaceAll('đ', '')
              .replaceAll('₫', '')
              .trim();
          if (text.isNotEmpty) {
            // Hỗ trợ số âm (khi còn lại bị âm)
            bool isNegative = text.startsWith('-');
            if (isNegative) text = text.substring(1);

            double parsedVal = double.tryParse(text) ?? 0.0;
            double newRemaining = isNegative ? -parsedVal : parsedVal;

            final mb = Get.find<BudgetService>().getBudgetForCategory(cat.id);
            double spent = mb != null ? mb.spentAmount : cat.spent;

            // Tiền phân bổ = Còn lại + Đã tiêu
            double newAllocated = newRemaining + spent;

            // Không cho phép tiền phân bổ < 0 (nếu muốn)
            if (newAllocated < 0) {
              newAllocated = 0.0;
              newRemaining = -spent; // Ép lại số dư nếu phân bổ = 0
            }

            groupAllocated += newAllocated;
            currentRemainingBudgets += newRemaining;
          }
        }
      }
      group.totalAllocated.value = groupAllocated;
    }

    allocatedAmount.value = currentRemainingBudgets;
    unallocatedAmount.value =
        totalWalletBalance.value - currentRemainingBudgets;
  }

  Future<void> saveBudgets() async {
    showLoading();
    final budgetService = Get.find<BudgetService>();
    final now = budgetService.currentTrackingMonth.value;
    final monthYearStr = "${now.month.toString().padLeft(2, '0')}-${now.year}";

    // Thu thập danh sách thay đổi
    final allocations = <Map<String, dynamic>>[];

    // Duyệt qua tất cả các nhóm và danh mục hiện tại để lấy dữ liệu thay đổi
    for (var group in categoryGroups) {
      for (var cat in group.categories) {
        final controller = textControllers[cat.id];
        if (controller != null) {
          String text = controller.text
              .replaceAll('.', '')
              .replaceAll(',', '')
              .replaceAll('đ', '')
              .replaceAll('₫', '')
              .trim();
          bool isNegative = text.startsWith('-');
          if (isNegative) text = text.substring(1);

          double parsedVal = double.tryParse(text) ?? 0.0;
          double newRemaining = isNegative ? -parsedVal : parsedVal;

          final mb = budgetService.getBudgetForCategory(cat.id);
          double spent = mb != null ? mb.spentAmount : cat.spent;
          double rollover = mb != null ? mb.rolloverAmount : 0.0;

          double newTotalAllocated = newRemaining + spent;
          if (newTotalAllocated < 0) newTotalAllocated = 0.0;

          double newBudgetedAmount = newTotalAllocated - rollover;

          if (mb == null ||
              mb.budgetedAmount != newBudgetedAmount ||
              newBudgetedAmount != cat.defaultBudget) {
            allocations.add({
              'categoryId': cat.id,
              'amount': newBudgetedAmount,
            });
          }
        }
      }
    }

    if (allocations.isEmpty) {
      hideLoading();
      Get.back();
      return;
    }

    final result = await ErrorHandler.execute(() async {
      for (var alloc in allocations) {
        final catId = alloc['categoryId'];
        final newBudgetedAmount = alloc['amount'];

        final group = categoryGroups.firstWhere(
          (g) => g.categories.any((c) => c.id == catId),
        );
        final cat = group.categories.firstWhere((c) => c.id == catId);

        if (newBudgetedAmount != cat.defaultBudget) {
          await categoryRepository.updateCategory(
            cat.id,
            cat.name,
            cat.iconName,
            cat.color,
            defaultBudget: newBudgetedAmount,
          );
        }

        final mb = budgetService.getBudgetForCategory(cat.id);
        if (mb != null) {
          if (mb.budgetedAmount != newBudgetedAmount) {
            await categoryRepository.updateMonthlyBudget(
              mb.id,
              newBudgetedAmount,
            );
          }
        } else {
          await categoryRepository.createMonthlyBudget(
            categoryId: cat.id,
            monthYear: monthYearStr,
            budgetedAmount: newBudgetedAmount,
            spentAmount: cat.spent,
          );
        }
      }
    }, tag: "SAVE_BUDGET_DISTRIBUTION");

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage(
          "Lỗi",
          "Không thể lưu phân bổ ngân sách: ${failure.message}",
        );
      },
      (_) {
        Get.find<BudgetService>().refreshData();
        Get.back(result: true);
      },
    );
  }

  String formatCurrency(double amount) {
    String numStr = amount.toStringAsFixed(0);
    final formatted = numStr.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formattedđ';
  }

  @override
  void onClose() {
    // Xóa listener và dispose
    for (var controller in textControllers.values) {
      controller.removeListener(_calculateTotals);
      controller.dispose();
    }
    super.onClose();
  }
}
