import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/core/services/budget_service.dart';

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

  Future<void> fetchData() async {
    final userId = currentUserId.value;
    if (userId.isEmpty) {
      return;
    }

    showLoading();

    final result = await ErrorHandler.execute(() async {
      // 1. Đồng bộ tổng ngân sách từ BudgetService (Nguồn chân lý duy nhất)
      totalWalletBalance.value =
          Get.find<BudgetService>().totalWalletBalance.value;

      final types = await categoryRepository.getCategoryTypes(userId);

      if (types.isEmpty) {
        categoryGroups.clear();
      } else {
        List<String> typeIds = [];
        for (var type in types) {
          typeIds.add(type.id);
        }

        final categories = await categoryRepository.getCategories(typeIds);

        for (var category in categories) {
          final mb = Get.find<BudgetService>().getBudgetForCategory(
            category.id,
          );
          double remaining = mb != null
              ? (mb.budgetedAmount + mb.rolloverAmount) - mb.spentAmount
              : category.remaining;

          // Format số tiền (vd: 500000 -> "500.000") để nhét vào TextField
          String currentAmount = formatCurrency(
            remaining,
          ).replaceAll('đ', '').trim();

          bool hasInputController = textControllers.containsKey(category.id);

          if (hasInputController == false) {
            // Nếu chưa có -> Tạo ô input mới
            final newController = TextEditingController(text: currentAmount);

            newController.addListener(_calculateTotals);

            textControllers[category.id] = newController;
          } else {
            textControllers[category.id]!.text = currentAmount;
          }
        }

        final List<BudgetDistributionGroup> distributionGroups = [];

        // Chạy qua từng nhóm (Thiết yếu, Mong muốn...)
        for (var type in types) {
          List<CategoryModel> categoriesInGroup = [];

          // Đi tìm các hạng mục con có ID nhóm trùng với ID của nhóm hiện tại và đang active
          for (var category in categories) {
            if (category.categoryTypeId == type.id && category.isActive) {
              categoriesInGroup.add(category);
            }
          }

          if (categoriesInGroup.isNotEmpty) {
            var newGroup = BudgetDistributionGroup(
              type.id,
              type.name,
              categoriesInGroup,
            );
            distributionGroups.add(newGroup);
          }
        }

        // Gán danh sách đã gom nhóm xong vào biến Observables để màn hình tự động vẽ lại
        categoryGroups.value = distributionGroups;
      }

      _calculateTotals();
    }, tag: "FETCH_BUDGET_DISTRIBUTION");

    // Tắt hiệu ứng loading
    hideLoading();

    // Bắt lỗi nếu quá trình lấy dữ liệu phía trên có vấn đề
    result.fold(
      (failure) {
        // Hiển thị thông báo màu đỏ báo lỗi cho user
        showErrorMessage("Lỗi", "Không thể tải dữ liệu: ${failure.message}");
      },
      (_) {
        // Không cần làm gì thêm
      },
    );
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
              .replaceAll('đ', '')
              .replaceAll(',', '')
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

    final result = await ErrorHandler.execute(() async {
      // Duyệt qua tất cả các nhóm và danh mục hiện tại
      for (var group in categoryGroups) {
        for (var cat in group.categories) {
          final controller = textControllers[cat.id];
          if (controller != null) {
            String text = controller.text
                .replaceAll('.', '')
                .replaceAll('đ', '')
                .replaceAll(',', '')
                .trim();
            bool isNegative = text.startsWith('-');
            if (isNegative) text = text.substring(1);

            double parsedVal = double.tryParse(text) ?? 0.0;
            double newRemaining = isNegative ? -parsedVal : parsedVal;

            final mb = budgetService.getBudgetForCategory(cat.id);
            double spent = mb != null ? mb.spentAmount : cat.spent;
            double rollover = mb != null ? mb.rolloverAmount : 0.0;

            // Tổng ngân sách cần có (Allocated)
            double newTotalAllocated = newRemaining + spent;
            if (newTotalAllocated < 0) newTotalAllocated = 0.0;

            // Số tiền cần nạp mới (Budgeted Amount) = Tổng Allocated - Tiền Cộng dồn
            double newBudgetedAmount = newTotalAllocated - rollover;

            // Cập nhật defaultBudget trên Category (template)
            if (newBudgetedAmount != cat.defaultBudget) {
              await categoryRepository.updateCategory(
                cat.id,
                cat.name,
                cat.iconName,
                cat.color,
                defaultBudget: newBudgetedAmount,
              );
            }

            // Cập nhật hoặc tạo mới MonthlyBudget
            if (mb != null) {
              // Đã có → chỉ update budgetedAmount
              if (mb.budgetedAmount != newBudgetedAmount) {
                await categoryRepository.updateMonthlyBudget(
                  mb.id,
                  newBudgetedAmount,
                );
              }
            } else {
              // Chưa có → tạo mới row MonthlyBudget cho tháng hiện tại
              await categoryRepository.createMonthlyBudget(
                categoryId: cat.id,
                monthYear: monthYearStr,
                budgetedAmount: newBudgetedAmount,
                spentAmount: spent,
              );
            }
          }
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
        Get.back();
        Get.find<BudgetService>().refreshData();
        // Hiện thông báo thành công
        Get.snackbar(
          "Thành công",
          "Đã lưu cấu hình ngân sách",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
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
