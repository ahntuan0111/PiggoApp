import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'dart:convert';

class CategoryController extends BaseController {
  final CategoryRepository categoryRepo = Get.find<CategoryRepository>();

  // Danh sách các nhóm (Mong muốn, Thiết yếu...)
  var categoryTypes = <CategoryTypeModel>[].obs;
  // Danh sách chi tiết các danh mục (Cafe, Ăn uống)
  var categories = <CategoryModel>[].obs;

  var isInitialLoading = true.obs;

  @override
  void onReady() {
    super.onReady();
    fetchData();
  }

  Future<void> fetchData() async {
    final storage = Get.find<StorageService>();
    final userId = storage.read<String>(AppKeys.userId) ?? '';
    if (userId.isEmpty) return;

    final localDb = Get.find<LocalDatabaseService>();
    final typesData = await localDb.getCategoryTypes();
    final catsData = await localDb.getCategories();

    // Nếu có mạng, đồng bộ mới nhất trước khi gán
    final networkService = Get.find<NetworkService>();
    if (!networkService.isOffline.value) {
      await Get.find<BudgetService>().refreshData();
      final freshTypes = await localDb.getCategoryTypes();
      final freshCats = await localDb.getCategories();
      categoryTypes.assignAll(
        freshTypes.map((e) => CategoryTypeModel.fromMap(e)).toList(),
      );
      categories.assignAll(
        freshCats
            .map((e) => CategoryModel.fromMap(e))
            .where((c) => c.isActive)
            .toList(),
      );
    } else {
      categoryTypes.assignAll(
        typesData.map((e) => CategoryTypeModel.fromMap(e)).toList(),
      );
      categories.assignAll(
        catsData
            .map((e) => CategoryModel.fromMap(e))
            .where((c) => c.isActive)
            .toList(),
      );
    }

    isInitialLoading.value = false;
  }

  Future<void> createCategoryType(String name) async {
    if (name.trim().isEmpty) return;

    showLoading();
    final storage = Get.find<StorageService>();
    final userId = storage.read<String>(AppKeys.userId) ?? '';
    final networkService = Get.find<NetworkService>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    final localDb = Get.find<LocalDatabaseService>();

    if (userId.isEmpty) {
      hideLoading();
      showErrorMessage("Lỗi", "Không tìm thấy thông tin người dùng.");
      return;
    }

    int maxPriority = 0;
    if (categoryTypes.isNotEmpty) {
      maxPriority = categoryTypes
          .map((e) => e.priority)
          .reduce((a, b) => a > b ? a : b);
    }

    if (networkService.isOffline.value) {
      final tempId = 'offline_\${DateTime.now().millisecondsSinceEpoch}';
      final payload = jsonEncode({
        'name': name.trim(),
        'priority': maxPriority + 1,
        'tempId': tempId,
      });
      await offlineSyncService.queueManualTask('CREATE_CATEGORY_TYPE', payload);

      final newType = CategoryTypeModel(
        id: tempId,
        ownerId: userId,
        name: name.trim(),
        priority: maxPriority + 1,
      );

      final typesDb = List<Map<String, dynamic>>.from(
        await localDb.getCategoryTypes(),
      );
      typesDb.add(newType.toMap());
      await localDb.saveCategoryTypes(typesDb);

      hideLoading();
      Get.back();
      showSuccessMessage(
        "Đã lưu (Ngoại tuyến)",
        "Dữ liệu sẽ được đồng bộ khi có mạng",
      );
      await fetchData();
    } else {
      final result = await ErrorHandler.execute(() async {
        await categoryRepo.createCategoryType(
          userId,
          name.trim(),
          maxPriority + 1,
        );
      }, tag: "CREATE_CATEGORY_TYPE");

      hideLoading();
      await result.fold(
        (failure) async {
          showErrorMessage(
            "Lỗi",
            "Không thể tạo nhóm danh mục: ${failure.message}",
          );
        },
        (_) async {
          Get.back();
          showSuccessMessage("Thành công", "Đã thêm nhóm danh mục");
          await fetchData();
        },
      );
    }
  }

  Future<void> createCategory(
    String typeId,
    String name,
    String iconName,
  ) async {
    if (name.trim().isEmpty) {
      showErrorMessage("Lỗi", "Vui lòng nhập tên danh mục");
      return;
    }

    showLoading();
    final networkService = Get.find<NetworkService>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    final localDb = Get.find<LocalDatabaseService>();
    final color = '#FDEBB2';

    if (networkService.isOffline.value) {
      final tempId = 'offline_\${DateTime.now().millisecondsSinceEpoch}';
      final payload = jsonEncode({
        'typeId': typeId,
        'name': name.trim(),
        'iconName': iconName,
        'color': color,
        'tempId': tempId,
      });
      await offlineSyncService.queueManualTask('CREATE_CATEGORY', payload);

      final newCat = CategoryModel(
        id: tempId,
        categoryTypeId: typeId,
        name: name.trim(),
        color: color,
        iconName: iconName,
      );

      final catsDb = List<Map<String, dynamic>>.from(
        await localDb.getCategories(),
      );
      catsDb.add(newCat.toMap());
      await localDb.saveCategories(catsDb);

      hideLoading();
      Get.back();
      showSuccessMessage(
        "Đã lưu (Ngoại tuyến)",
        "Dữ liệu sẽ được đồng bộ khi có mạng",
      );
      await fetchData();
    } else {
      final result = await ErrorHandler.execute(() async {
        await categoryRepo.createCategory(typeId, name.trim(), iconName, color);
      }, tag: "CREATE_CATEGORY");

      hideLoading();
      await result.fold(
        (failure) async {
          showErrorMessage("Lỗi", "Không thể tạo danh mục: ${failure.message}");
        },
        (_) async {
          Get.back();
          showSuccessMessage('Thành công', 'Đã thêm danh mục mới');
          await fetchData();
        },
      );
    }
  }

  Future<void> updateCategoryType(String typeId, String name) async {
    if (name.trim().isEmpty) return;

    showLoading();
    final networkService = Get.find<NetworkService>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    final localDb = Get.find<LocalDatabaseService>();

    if (networkService.isOffline.value) {
      final payload = jsonEncode({'id': typeId, 'name': name.trim()});
      await offlineSyncService.queueManualTask('UPDATE_CATEGORY_TYPE', payload);
      await localDb.updateCategoryType(typeId, name.trim());

      hideLoading();
      Get.back();
      showSuccessMessage(
        "Đã lưu (Ngoại tuyến)",
        "Dữ liệu sẽ được đồng bộ khi có mạng",
      );
      await fetchData();
    } else {
      final result = await ErrorHandler.execute(() async {
        await categoryRepo.updateCategoryType(typeId, name.trim());
      }, tag: "UPDATE_CATEGORY_TYPE");
      hideLoading();

      await result.fold(
        (failure) async {
          showErrorMessage(
            "Lỗi",
            failure.message.contains("Invalid `rowId`") ||
                    failure.message.contains("could not be found")
                ? "Dữ liệu không tồn tại hoặc đã bị xóa trên hệ thống."
                : "Không thể cập nhật nhóm danh mục: ${failure.message}",
          );
        },
        (_) async {
          await fetchData();
          Get.back(); // Đóng dialog
          showSuccessMessage(
            "Thành công",
            "Đã cập nhật nhóm danh mục",
          ); // Dialog đã đóng, Route cha vẫn sống
        },
      );
    }
  }

  Future<void> deleteCategoryType(String typeId) async {
    showLoading();
    final networkService = Get.find<NetworkService>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    final localDb = Get.find<LocalDatabaseService>();

    if (networkService.isOffline.value) {
      final payload = jsonEncode({'id': typeId});
      await offlineSyncService.queueManualTask('DELETE_CATEGORY_TYPE', payload);
      await localDb.deleteCategoryType(typeId);

      hideLoading();
      showSuccessMessage(
        "Đã lưu (Ngoại tuyến)",
        "Dữ liệu sẽ được đồng bộ khi có mạng",
      );
      await fetchData();
    } else {
      final result = await ErrorHandler.execute(() async {
        await categoryRepo.deleteCategoryType(typeId);
      }, tag: "DELETE_CATEGORY_TYPE");
      hideLoading();

      await result.fold(
        (failure) async {
          showErrorMessage(
            "Lỗi",
            failure.message.contains("Invalid `rowId`") ||
                    failure.message.contains("could not be found")
                ? "Dữ liệu không tồn tại hoặc đã bị xóa trên hệ thống."
                : "Không thể xóa nhóm danh mục: ${failure.message}",
          );
        },
        (_) async {
          await fetchData();
          showSuccessMessage("Thành công", "Đã xóa nhóm danh mục");
        },
      );
    }
  }

  Future<void> updateCategory(
    String categoryId,
    String name,
    String iconName,
    String color,
  ) async {
    if (name.trim().isEmpty) {
      showErrorMessage("Lỗi", "Vui lòng nhập tên danh mục");
      return;
    }

    showLoading();
    final networkService = Get.find<NetworkService>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    final localDb = Get.find<LocalDatabaseService>();

    if (networkService.isOffline.value) {
      final payload = jsonEncode({
        'id': categoryId,
        'name': name.trim(),
        'iconName': iconName,
        'color': color,
      });
      await offlineSyncService.queueManualTask('UPDATE_CATEGORY', payload);
      await localDb.updateCategory(categoryId, name.trim(), iconName, color);

      hideLoading();
      Get.back();
      showSuccessMessage(
        "Đã lưu (Ngoại tuyến)",
        "Dữ liệu sẽ được đồng bộ khi có mạng",
      );
      await fetchData();
    } else {
      final result = await ErrorHandler.execute(() async {
        await categoryRepo.updateCategory(
          categoryId,
          name.trim(),
          iconName,
          color,
        );
      }, tag: "UPDATE_CATEGORY");
      hideLoading();

      await result.fold(
        (failure) async {
          showErrorMessage(
            "Lỗi",
            failure.message.contains("Invalid `rowId`") ||
                    failure.message.contains("could not be found")
                ? "Dữ liệu không tồn tại hoặc đã bị xóa trên hệ thống."
                : "Không thể cập nhật danh mục: ${failure.message}",
          );
        },
        (_) async {
          await fetchData();
          Get.back(); // Đóng dialog
          showSuccessMessage(
            "Thành công",
            "Đã cập nhật danh mục",
          ); // Dialog đã đóng, Route cha vẫn sống
        },
      );
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    showLoading();
    final networkService = Get.find<NetworkService>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    final localDb = Get.find<LocalDatabaseService>();

    if (networkService.isOffline.value) {
      final payload = jsonEncode({'id': categoryId});
      await offlineSyncService.queueManualTask('DELETE_CATEGORY', payload);
      await localDb.deleteCategory(categoryId);

      hideLoading();
      showSuccessMessage(
        "Đã lưu (Ngoại tuyến)",
        "Dữ liệu sẽ được đồng bộ khi có mạng",
      );
      await fetchData();
    } else {
      final result = await ErrorHandler.execute(() async {
        await categoryRepo.deleteCategory(categoryId);
      }, tag: "DELETE_CATEGORY");
      hideLoading();

      await result.fold(
        (failure) async {
          showErrorMessage(
            "Lỗi",
            failure.message.contains("Invalid `rowId`") ||
                    failure.message.contains("could not be found")
                ? "Dữ liệu không tồn tại hoặc đã bị xóa trên hệ thống."
                : "Không thể xóa danh mục: ${failure.message}",
          );
        },
        (_) async {
          await fetchData();
          showSuccessMessage("Thành công", "Đã xóa danh mục");
        },
      );
    }
  }
}
