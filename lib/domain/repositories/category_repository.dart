import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';

class CategoryRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;

  CategoryRepository(this._appwrite);

  Future<void> createDefaultCategoryTypes(String userId) async {
    return handleAppwriteError(() async {
      final defaultTypes = [
        {'name': 'Cố định', 'priority': 1},
        {'name': 'Thiết yếu', 'priority': 2},
        {'name': 'Tiết kiệm', 'priority': 3},
      ];

      for (var type in defaultTypes) {
        await _appwrite.tables.createRow(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.categoriesTypeTableId,
          rowId: ID.unique(),
          data: {
            'ownerId': userId,
            'name': type['name'],
            'priority': type['priority'],
          },
        );
      }
    });
  }

  Future<List<CategoryTypeModel>> getCategoryTypes(String userId) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTypeTableId,
        queries: [Query.equal('ownerId', userId), Query.orderAsc('priority')],
      );
      return response.rows
          .map((row) => CategoryTypeModel.fromMap(row.data))
          .toList();
    });
  }

  Future<List<CategoryModel>> getCategories(List<String> typeIds) async {
    if (typeIds.isEmpty) return [];
    return handleAppwriteError(() async {
      List<CategoryModel> allCategories = [];
      String currentMonthStr =
          "${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}";

      for (String typeId in typeIds) {
        final response = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.categoriesTableId,
          queries: [Query.equal('categoryTypes', typeId)],
        );

        for (var row in response.rows) {
          CategoryModel cat = CategoryModel.fromMap(row.data);

          // Thử tìm budget của tháng hiện tại cho category này
          final budgetResponse = await _appwrite.tables.listRows(
            databaseId: _appwrite.databaseId,
            tableId: _appwrite.monthlyBudgetsTableId,
            queries: [
              Query.equal('categories', cat.id),
              Query.equal('monthYear', currentMonthStr),
            ],
          );

          if (budgetResponse.rows.isNotEmpty) {
            cat.spent = (budgetResponse.rows.first.data['spentAmount'] ?? 0)
                .toDouble();
          } else {
            cat.spent = 0.0;
          }

          allCategories.add(cat);
        }
      }
      return allCategories;
    });
  }

  Future<CategoryTypeModel> createCategoryType(
    String userId,
    String name,
    int priority,
  ) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTypeTableId,
        rowId: ID.unique(),
        data: {'ownerId': userId, 'name': name, 'priority': priority},
      );
      return CategoryTypeModel.fromMap(response.data);
    });
  }

  Future<CategoryModel> createCategory(
    String typeId,
    String name,
    String iconName,
    String color,
  ) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTableId,
        rowId: ID.unique(),
        data: {
          'categoryTypes': typeId,
          'name': name,
          'iconName': iconName,
          'color': color,
        },
      );
      return CategoryModel.fromMap(response.data);
    });
  }

  Future<CategoryTypeModel> updateCategoryType(
    String typeId,
    String name,
  ) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTypeTableId,
        rowId: typeId,
        data: {'name': name},
      );
      return CategoryTypeModel.fromMap(response.data);
    });
  }

  Future<void> deleteCategoryType(String typeId) async {
    return handleAppwriteError(() async {
      await _appwrite.tables.deleteRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTypeTableId,
        rowId: typeId,
      );
    });
  }

  Future<CategoryModel> updateCategory(
    String categoryId,
    String name,
    String iconName,
    String color, {
    double? defaultBudget,
  }) async {
    return handleAppwriteError(() async {
      final data = <String, dynamic>{
        'name': name,
        'iconName': iconName,
        'color': color,
      };
      if (defaultBudget != null) {
        data['defaultBudget'] = defaultBudget;
      }
      final response = await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTableId,
        rowId: categoryId,
        data: data,
      );
      return CategoryModel.fromMap(response.data);
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    return handleAppwriteError(() async {
      await _appwrite.tables.deleteRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTableId,
        rowId: categoryId,
      );
    });
  }
}
