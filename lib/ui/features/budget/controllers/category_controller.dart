import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/services/budget_service.dart';

class CategoryController extends BaseController {
  final CategoryRepository categoryRepo = Get.find<CategoryRepository>();

  // Danh sách các nhóm (Mong muốn, Thiết yếu...)
  var categoryTypes = <CategoryTypeModel>[].obs;
  // Danh sách chi tiết các danh mục (Cafe, Ăn uống)
  var categories = <CategoryModel>[].obs;
  var isInitialLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchData();
  }

  Future<void> fetchData() async {
    isInitialLoading.value = true;
    showLoading();
    final result = await ErrorHandler.execute(() async {
      final storage = Get.find<StorageService>();
      final userId = storage.read<String>(AppKeys.userId) ?? '';
      final types = await categoryRepo.getCategoryTypes(userId);
      final cats = await categoryRepo.getCategories(null, userId);
      return {'types': types, 'categories': cats};
    }, tag: "FETCH_CATEGORIES");

    hideLoading();
    isInitialLoading.value = false;
    await result.fold(
      (failure) async {
        showErrorMessage("Lỗi", failure.message);
      },
      (data) async {
        categoryTypes.assignAll(data['types'] as List<CategoryTypeModel>);
        categories.assignAll(data['categories'] as List<CategoryModel>);
        await Get.find<BudgetService>().refreshData();
      },
    );
  }

  // Lấy các category thuộc về 1 Type cụ thể (chỉ lấy các danh mục đang hoạt động)
  List<CategoryModel> getCategoriesForType(String typeId) {
    return categories
        .where((c) => c.categoryTypeId == typeId && c.isActive)
        .toList();
  }

  Future<void> createCategoryType(String name) async {
    if (name.trim().isEmpty) return;

    showLoading();
    final storage = Get.find<StorageService>();
    final userId = storage.read<String>(AppKeys.userId) ?? '';

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
        await fetchData();
        Get.back();
        showSuccessMessage("Thành công", "Đã tạo nhóm danh mục");
      },
    );
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
    final color = '#FDEBB2';
    final storage = Get.find<StorageService>();
    final userId = storage.read<String>(AppKeys.userId) ?? '';

    final result = await ErrorHandler.execute(() async {
      await categoryRepo.createCategory(
        typeId,
        name.trim(),
        iconName,
        color,
        userId: userId,
      );
    }, tag: "CREATE_CATEGORY");

    hideLoading();
    await result.fold(
      (failure) async {
        showErrorMessage("Lỗi", "Không thể tạo danh mục: ${failure.message}");
      },
      (_) async {
        await fetchData();
        Get.back();
        showSuccessMessage('Thành công', 'Đã thêm danh mục mới');
      },
    );
  }

  Future<void> updateCategoryType(String typeId, String name) async {
    if (name.trim().isEmpty) return;

    showLoading();
    final storage = Get.find<StorageService>();
    final userId = storage.read<String>(AppKeys.userId) ?? '';

    final result = await ErrorHandler.execute(() async {
      await categoryRepo.updateCategoryType(
        typeId,
        name.trim(),
        userId: userId,
      );
    }, tag: "UPDATE_CATEGORY_TYPE");
    hideLoading();

    await result.fold(
      (failure) async {
        showErrorMessage(
          "Lỗi",
          "Không thể cập nhật nhóm danh mục: ${failure.message}",
        );
      },
      (_) async {
        await fetchData();
        Get.back();
        showSuccessMessage("Thành công", "Đã cập nhật nhóm danh mục");
      },
    );
  }

  Future<void> deleteCategoryType(String typeId) async {
    showLoading();
    final storage = Get.find<StorageService>();
    final userId = storage.read<String>(AppKeys.userId) ?? '';

    final result = await ErrorHandler.execute(() async {
      await categoryRepo.deleteCategoryType(typeId, userId: userId);
    }, tag: "DELETE_CATEGORY_TYPE");
    hideLoading();

    await result.fold(
      (failure) async {
        showErrorMessage(
          "Lỗi",
          "Không thể xóa nhóm danh mục: ${failure.message}",
        );
      },
      (_) async {
        await fetchData();
        showSuccessMessage("Thành công", "Đã xóa nhóm danh mục");
      },
    );
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
    final storage = Get.find<StorageService>();
    final userId = storage.read<String>(AppKeys.userId) ?? '';

    final result = await ErrorHandler.execute(() async {
      await categoryRepo.updateCategory(
        categoryId,
        name.trim(),
        iconName,
        color,
        userId: userId,
      );
    }, tag: "UPDATE_CATEGORY");
    hideLoading();

    await result.fold(
      (failure) async {
        showErrorMessage(
          "Lỗi",
          "Không thể cập nhật danh mục: ${failure.message}",
        );
      },
      (_) async {
        await fetchData();
        Get.back();
        showSuccessMessage("Thành công", "Đã cập nhật danh mục");
      },
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    showLoading();
    final storage = Get.find<StorageService>();
    final userId = storage.read<String>(AppKeys.userId) ?? '';

    final result = await ErrorHandler.execute(() async {
      await categoryRepo.deleteCategory(categoryId, userId: userId);
    }, tag: "DELETE_CATEGORY");
    hideLoading();

    await result.fold(
      (failure) async {
        showErrorMessage(
          "Lỗi",
          "Không thể xóa danh mục: ${failure.message}",
        );
      },
      (_) async {
        await fetchData();
        showSuccessMessage("Thành công", "Đã xóa danh mục");
      },
    );
  }
}
