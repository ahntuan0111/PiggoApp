import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/compensation_source.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/ui/widgets/bottom_sheet/select_source_bottom_sheet.dart';
import 'package:flutter/material.dart';

class OverspentCompensationController extends BaseController with BudgetAware {
  final CategoryRepository _categoryRepo = Get.find<CategoryRepository>();

  late CategoryModel targetCategory;
  final sources = <CompensationSource>[].obs;
  
  // Quản lý TextEditingController cho mỗi nguồn
  final textControllers = <int, TextEditingController>{};

  @override
  void onInit() {
    super.onInit();
    // Khởi tạo từ arguments (truyền sang từ HomeScreen)
    targetCategory = Get.arguments as CategoryModel;
  }

  @override
  void onClose() {
    for (var controller in textControllers.values) {
      controller.dispose();
    }
    super.onClose();
  }

  // Tổng số tiền bù vào
  double get totalCompensated {
    return sources.fold(0.0, (sum, item) => sum + item.amountToCompensate);
  }

  // Số tiền còn lại mới (âm ban đầu + tiền bù vào)
  // Lưu ý: targetCategory.remaining có thể tính bằng: targetCategory.defaultBudget - targetCategory.spent
  // Trong model, spent và defaultBudget có sẵn.
  double get newRemaining {
    double currentRemaining =
        targetCategory.defaultBudget - targetCategory.spent;
    return currentRemaining + totalCompensated;
  }

  // Đã bù đủ tiền (hết âm)
  bool get isFullyCompensated => newRemaining >= 0;

  void openSelectSourceBottomSheet({int? indexToReplace}) {
    // Thu thập các ID đã chọn để ẩn đi
    final excludeIds = [targetCategory.id, ...sources.map((s) => s.sourceId)];
    // Nếu đang replace, thì không ẩn ID đang bị thay thế
    if (indexToReplace != null) {
      excludeIds.remove(sources[indexToReplace].sourceId);
    }

    Get.bottomSheet(
      SelectSourceBottomSheet(
        unallocatedAmount: budgetService.unallocatedAmount.value,
        categoryGroups: budgetService.categoryGroups,
        currentCategoryId: targetCategory.id,
        excludeCategoryIds: excludeIds,
        onSelected: (id, name, availableAmount, icon) {
          if (indexToReplace != null) {
            // Thay thế nguồn hiện tại
            sources[indexToReplace] = CompensationSource(
              sourceId: id,
              sourceName: name,
              iconName: icon,
              availableAmount: availableAmount,
              amountToCompensate: 0, // Reset số tiền nhập
            );
            textControllers[indexToReplace]?.text = '';
            sources.refresh();
          } else {
            // Thêm nguồn mới
            int newIndex = sources.length;
            sources.add(
              CompensationSource(
                sourceId: id,
                sourceName: name,
                iconName: icon,
                availableAmount: availableAmount,
                amountToCompensate: 0,
              ),
            );
            textControllers[newIndex] = TextEditingController();
          }
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void updateSourceAmount(int index, double amount) {
    if (index >= 0 && index < sources.length) {
      sources[index].amountToCompensate = amount;
      sources.refresh(); // Kích hoạt RxList update
    }
  }

  void removeSource(int index) {
    if (index >= 0 && index < sources.length) {
      sources.removeAt(index);
      textControllers[index]?.dispose();
      
      // Shift controllers down
      for (int i = index; i < sources.length; i++) {
        textControllers[i] = textControllers[i + 1]!;
      }
      textControllers.remove(sources.length);
    }
  }

  Future<void> saveCompensation() async {
    // Nếu chưa nhập tiền vào sources thì không cho lưu
    if (sources.isEmpty || totalCompensated <= 0) {
      showErrorMessage(
        'Lỗi',
        'Vui lòng thêm nguồn tiền và nhập số tiền bù đắp.',
      );
      return;
    }

    // Kiểm tra xem có nguồn nào bị lấy lố tiền không (vượt quá availableAmount)
    for (var source in sources) {
      if (source.amountToCompensate > source.availableAmount) {
        showErrorMessage(
          'Lỗi',
          'Số tiền bù đắp từ nguồn "${source.sourceName}" vượt quá số dư khả dụng!',
        );
        return;
      }
    }

    showLoading();
    final result = await ErrorHandler.execute(() async {
      // 1. Cập nhật category bị âm (Cộng tiền)
      double newTargetBudget = targetCategory.defaultBudget + totalCompensated;
      await _categoryRepo.updateCategory(
        targetCategory.id,
        targetCategory.name,
        targetCategory.iconName,
        targetCategory.color,
        defaultBudget: newTargetBudget,
      );

      // 2. Cập nhật các nguồn bị lấy tiền (Trừ tiền)
      for (var source in sources) {
        if (source.amountToCompensate > 0 && source.sourceId != 'unallocated') {
          // Lấy category gốc từ BudgetService để biết thông tin hiện tại
          final sourceCatList = budgetService.categories
              .where((c) => c.categoryModel.id == source.sourceId)
              .toList();

          if (sourceCatList.isNotEmpty) {
            final sourceCat = sourceCatList.first.categoryModel;
            double newSourceBudget =
                sourceCat.defaultBudget - source.amountToCompensate;
            await _categoryRepo.updateCategory(
              sourceCat.id,
              sourceCat.name,
              sourceCat.iconName,
              sourceCat.color,
              defaultBudget: newSourceBudget,
            );
          }
        }
      }
    }, tag: "SAVE_COMPENSATION");

    hideLoading();
    result.fold((failure) => showErrorMessage('Lỗi', failure.message), (_) {
      refreshBudget(); // Tải lại toàn bộ dữ liệu Budget
      Get.back(); // Đóng màn hình
      showSuccessMessage('Thành công', 'Đã bù đắp chi tiêu thành công.');
    });
  }
}
