import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/data/models/category_model.dart';

class GoalCreateController extends BaseController with BudgetAware {
  final GoalRepository goalRepository = Get.find<GoalRepository>();
  final CategoryRepository _categoryRepository = Get.find<CategoryRepository>();

  final nameController = TextEditingController();
  final targetAmountController = TextEditingController();
  final selectedDeadline = Rxn<DateTime>();
  final selectedIcon = '1.png'.obs;

  void pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDeadline.value ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      selectedDeadline.value = picked;
    }
  }

  Future<void> createGoal() async {
    if (nameController.text.trim().isEmpty) {
      showErrorMessage('Lỗi', 'Vui lòng nhập tên mục tiêu');
      return;
    }

    final targetAmountStr = targetAmountController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final targetAmount = double.tryParse(targetAmountStr) ?? 0;

    if (targetAmount <= 0) {
      showErrorMessage('Lỗi', 'Số tiền mục tiêu phải lớn hơn 0');
      return;
    }

    showLoading();

    final result = await ErrorHandler.execute(() async {
      // 1. Get CategoryType "Tiết kiệm"
      CategoryTypeModel savingType;
      final types = await _categoryRepository.getCategoryTypes(
        budgetService.currentUserId.value,
      );

      final existingType = types.firstWhereOrNull((t) => t.name == 'Tiết kiệm');
      if (existingType != null) {
        savingType = existingType;
      } else {
        if (types.isNotEmpty) {
          savingType = types.first;
        } else {
          throw Exception("Không tìm thấy Category Type nào để gắn mục tiêu");
        }
      }

      // 2. Create Category
      final createdCategory = await _categoryRepository.createCategory(
        savingType.id,
        nameController.text.trim(),
        selectedIcon.value,
        '0xFFD32F2F', // default color
        isActive: false, // Ẩn khỏi màn hình Budget/Transaction
      );

      // 3. Create Goal
      GoalModel newGoal = GoalModel(
        id: '',
        name: nameController.text.trim(),
        targetAmount: targetAmount,
        deadline: selectedDeadline.value,
        categoryId: createdCategory.id,
        status: 'ACTIVE',
      );

      await goalRepository.createGoal(newGoal);
    }, tag: "CREATE_GOAL");

    hideLoading();

    result.fold((failure) => showErrorMessage("Lỗi", failure.message), (
      _,
    ) async {
      // Tải lại dữ liệu ở màn hình trước
      await budgetService.refreshData();
      Get.back(result: true); // Báo hiệu thành công
    });
  }

  @override
  void onClose() {
    nameController.dispose();
    targetAmountController.dispose();
    super.onClose();
  }
}
