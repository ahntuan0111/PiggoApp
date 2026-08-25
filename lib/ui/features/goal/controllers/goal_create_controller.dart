import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/core/utils/offline_helper.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
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
      final networkService = Get.find<NetworkService>();
      final offlineSyncService = Get.find<OfflineSyncService>();
      final localDb = Get.find<LocalDatabaseService>();
      final isOffline = networkService.isOffline.value;

      final tempId = isOffline ? OfflineHelper.generateTempId() : '';

      // 1. Get CategoryType "Tiết kiệm"
      CategoryTypeModel savingType;
      final types = isOffline
          ? await localDb.getCategoryTypes().then(
              (list) => list.map((e) => CategoryTypeModel.fromMap(e)).toList(),
            )
          : await _categoryRepository.getCategoryTypes(
              budgetService.currentUserId.value,
            );

      final existingType = types.firstWhereOrNull((t) => t.name == 'Tiết kiệm');
      if (existingType != null) {
        savingType = existingType;
      } else {
        // Fallback to the first available category type if "Tiết kiệm" is somehow missing
        if (types.isNotEmpty) {
          savingType = types.first;
        } else {
          throw Exception("Không tìm thấy Category Type nào để gắn mục tiêu");
        }
      }

      // 2. Create Category
      CategoryModel createdCategory;
      if (isOffline) {
        createdCategory = CategoryModel(
          id: "${tempId}_cat",
          categoryTypeId: savingType.id,
          name: nameController.text.trim(),
          iconName: selectedIcon.value,
          color: '0xFFD32F2F',
          isActive: false, // Ẩn khỏi màn hình Budget/Transaction
        );
        await localDb.insertLocalCategory(createdCategory.toMap());
        final payload = jsonEncode({
          'typeId': createdCategory.categoryTypeId,
          'name': createdCategory.name,
          'iconName': createdCategory.iconName,
          'color': createdCategory.color,
          'tempId': createdCategory.id,
          'isActive': false,
        });
        await offlineSyncService.queueManualTask('CREATE_CATEGORY', payload);
      } else {
        createdCategory = await _categoryRepository.createCategory(
          savingType.id,
          nameController.text.trim(),
          selectedIcon.value,
          '0xFFD32F2F', // default color
          isActive: false, // Ẩn khỏi màn hình Budget/Transaction
        );
      }

      // 3. Create Goal
      GoalModel newGoal = GoalModel(
        id: isOffline ? tempId : '',
        name: nameController.text.trim(),
        targetAmount: targetAmount,
        deadline: selectedDeadline.value,
        categoryId: createdCategory.id,
        status: 'ACTIVE',
      );

      if (isOffline) {
        if (offlineSyncService.checkAndShowManualQueueFull()) return;
        await localDb.insertLocalGoal(newGoal.toMap()..['id'] = newGoal.id);
        final payload = jsonEncode({
          'goal': newGoal.toMap()..['id'] = newGoal.id,
          'category': createdCategory.toMap()..['id'] = createdCategory.id,
          'tempId': tempId,
        });
        await offlineSyncService.queueManualTask('CREATE_GOAL', payload);
      } else {
        await goalRepository.createGoal(newGoal);
      }
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
