import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/domain/repositories/wallet_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'dart:math' as math;

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
  final WalletRepository walletRepository = Get.find<WalletRepository>();

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
      final wallets = await walletRepository.getWallets(userId);

      double totalBalance = 0.0;
      for (var wallet in wallets) {
        totalBalance = totalBalance + wallet.balance;
      }
      // Lưu vào biến tổng để cập nhật lên UI
      totalWalletBalance.value = totalBalance;

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
          // Format số tiền (vd: 500000 -> "500.000") để nhét vào TextField
          String currentAmount = formatCurrency(
            category.remaining,
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

          // Đi tìm các hạng mục con có ID nhóm trùng với ID của nhóm hiện tại
          for (var category in categories) {
            if (category.categoryTypeId == type.id) {
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
    double currentAllocated = 0.0;
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
            
            // Tiền phân bổ = Còn lại + Đã tiêu
            double newAllocated = newRemaining + cat.spent;
            
            // Không cho phép tiền phân bổ < 0 (nếu muốn)
            if (newAllocated < 0) {
              newAllocated = 0.0;
              newRemaining = -cat.spent; // Ép lại số dư nếu phân bổ = 0
            }

            groupAllocated += newAllocated;
            currentRemainingBudgets += math.max(0, newRemaining);
          }
        }
      }
      group.totalAllocated.value = groupAllocated;
      currentAllocated += groupAllocated;
    }

    allocatedAmount.value = currentRemainingBudgets;
    unallocatedAmount.value =
        totalWalletBalance.value - currentRemainingBudgets;
  }

  Future<void> saveBudgets() async {
    showLoading();
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
            
            double newBudget = newRemaining + cat.spent;
            if (newBudget < 0) newBudget = 0.0;

            // Nếu có thay đổi, cập nhật lên DB
            if (newBudget != cat.defaultBudget) {
              await categoryRepository.updateCategory(
                cat.id,
                cat.name,
                cat.iconName,
                cat.color,
                defaultBudget: newBudget,
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
    return numStr.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        ) +
        'đ';
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
