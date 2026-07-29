import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/errors/error_handler.dart';

class CategoryController extends BaseController {
  final CategoryRepository categoryRepo = Get.find<CategoryRepository>();

  // Danh sách các nhóm (Mong muốn, Thiết yếu...)
  var categoryTypes = <CategoryTypeModel>[].obs;
  // Danh sách chi tiết các danh mục (Cafe, Ăn uống)
  var categories = <CategoryModel>[].obs;

  @override
  void onReady() {
    super.onReady();
    fetchData();
  }

  Future<void> fetchData() async {
    showLoading();

    final result = await ErrorHandler.execute(() async {
      final storage = Get.find<StorageService>();
      final userId = storage.read<String>(AppKeys.userId) ?? '';

      if (userId.isEmpty) return;

      final types = await categoryRepo.getCategoryTypes(userId);
      categoryTypes.assignAll(types);

      if (types.isNotEmpty) {
        final typeIds = types.map((e) => e.id).toList();
        final cats = await categoryRepo.getCategories(typeIds);
        final activeCats = cats.where((c) => c.isActive).toList();
        print("DEBUG: Fetched ${activeCats.length} active categories from DB.");
        categories.assignAll(activeCats);
        for (var c in activeCats) {
          print(
            "DEBUG: Category ${c.name} has categoryTypeId = ${c.categoryTypeId}",
          );
        }
      }
    }, tag: "FETCH_CATEGORIES");

    result.fold((failure) {
      showErrorMessage(
        "Lỗi",
        "Không thể tải danh sách ngân sách: ${failure.message}",
      );
    }, (_) {});

    hideLoading();
  }

  Future<void> createCategoryType(String name) async {
    if (name.trim().isEmpty) return;

    showLoading();
    final result = await ErrorHandler.execute(() async {
      final storage = Get.find<StorageService>();
      final userId = storage.read<String>(AppKeys.userId) ?? '';

      if (userId.isEmpty) {
        throw Exception("Không tìm thấy thông tin người dùng.");
      }

      int maxPriority = 0;
      if (categoryTypes.isNotEmpty) {
        maxPriority = categoryTypes
            .map((e) => e.priority)
            .reduce((a, b) => a > b ? a : b);
      }

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
        Get.back(); // Đóng bottom sheet TRƯỚC khi gọi fetchData
        await fetchData(); // Load lại data (hàm này tự show/hide loading)
        // showSuccessMessage("Thành công", "Đã tạo nhóm danh mục mới");
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
    final result = await ErrorHandler.execute(() async {
      final color = '#FDEBB2'; // Màu mặc định cho danh mục mới
      await categoryRepo.createCategory(typeId, name.trim(), iconName, color);
    }, tag: "CREATE_CATEGORY");

    hideLoading();

    await result.fold(
      (failure) async {
        showErrorMessage("Lỗi", "Không thể tạo danh mục: ${failure.message}");
      },
      (_) async {
        Get.back(); // Đóng bottom sheet TRƯỚC
        await fetchData(); // Load lại data tự quản lý loading
        // showSuccessMessage("Thành công", "Đã tạo danh mục mới");
      },
    );
  }

  Future<void> updateCategoryType(String typeId, String name) async {
    if (name.trim().isEmpty) return;

    showLoading();
    final result = await ErrorHandler.execute(() async {
      await categoryRepo.updateCategoryType(typeId, name.trim());
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
        Get.back(); // Đóng dialog
        await fetchData();
        showSuccessMessage("Thành công", "Đã cập nhật nhóm danh mục");
      },
    );
  }

  Future<void> deleteCategoryType(String typeId) async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      await categoryRepo.deleteCategoryType(typeId);
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
          "Không thể cập nhật danh mục: ${failure.message}",
        );
      },
      (_) async {
        Get.back(); // Đóng dialog
        await fetchData();
        showSuccessMessage("Thành công", "Đã cập nhật danh mục");
      },
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      await categoryRepo.deleteCategory(categoryId);
    }, tag: "DELETE_CATEGORY");
    hideLoading();

    await result.fold(
      (failure) async {
        showErrorMessage("Lỗi", "Không thể xóa danh mục: ${failure.message}");
      },
      (_) async {
        await fetchData();
        showSuccessMessage("Thành công", "Đã xóa danh mục");
      },
    );
  }
}
