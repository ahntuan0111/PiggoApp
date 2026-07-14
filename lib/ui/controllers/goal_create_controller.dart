import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/domain/repositories/goal_repository.dart';
import 'package:flutter/material.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:get/get.dart';
import 'package:appwrite/appwrite.dart';

class GoalCreateController extends BaseController with BudgetAware {
  final GoalRepository goalRepository = Get.find<GoalRepository>();
  final CategoryRepository categoryRepository = Get.find<CategoryRepository>();
  final AppwriteService appwriteService = Get.find<AppwriteService>();

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

    final targetAmountStr = targetAmountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final targetAmount = double.tryParse(targetAmountStr) ?? 0;

    if (targetAmount <= 0) {
      showErrorMessage('Lỗi', 'Số tiền mục tiêu phải lớn hơn 0');
      return;
    }

    showLoading();

    final result = await ErrorHandler.execute(() async {
      // 1. Get or Create CategoryType "Tiết kiệm lâu dài"
      CategoryTypeModel? savingType;
      try {
        final typeResponse = await appwriteService.tables.listRows(
          databaseId: appwriteService.databaseId,
          tableId: appwriteService.categoriesTypeTableId,
          queries: [Query.equal('name', 'Tiết kiệm lâu dài'), Query.equal('ownerId', budgetService.currentUserId.value)],
        );
        if (typeResponse.rows.isNotEmpty) {
          savingType = CategoryTypeModel.fromMap(typeResponse.rows.first.data);
        } else {
          // Tạo mới
          final newTypeResponse = await appwriteService.tables.createRow(
             databaseId: appwriteService.databaseId,
             tableId: appwriteService.categoriesTypeTableId,
             rowId: ID.unique(),
             data: {
               'ownerId': budgetService.currentUserId.value,
               'name': 'Tiết kiệm lâu dài',
               'priority': 99, // Đặt xuống cuối
             }
          );
          savingType = CategoryTypeModel.fromMap(newTypeResponse.data);
        }
      } catch (e) {
        throw Exception("Không thể xử lý Nhóm danh mục: $e");
      }

      // 2. Create Category
      final createdCategory = await categoryRepository.createCategory(
        savingType.id,
        nameController.text.trim(),
        selectedIcon.value,
        '0xFFD32F2F', // default color
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

    result.fold(
      (failure) => showErrorMessage("Lỗi", failure.message),
      (_) async {
        // Tải lại dữ liệu ở màn hình trước
        await budgetService.refreshData();
        Get.back(result: true); // Báo hiệu thành công
      }
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    targetAmountController.dispose();
    super.onClose();
  }
}
