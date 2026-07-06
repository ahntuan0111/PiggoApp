import 'package:appintern/core/network/appwrite_service.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/domain/repositories/appwrite_error_mixin.dart';

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
      for (String typeId in typeIds) {
        final response = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.categoriesTableId,
          queries: [Query.equal('categoryType', typeId)],
        );
        final cats = response.rows.map((row) => CategoryModel.fromMap(row.data)).toList();
        allCategories.addAll(cats);
      }
      return allCategories;
    });
  }

  Future<CategoryTypeModel> createCategoryType(String userId, String name, int priority) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTypeTableId,
        rowId: ID.unique(),
        data: {
          'ownerId': userId,
          'name': name,
          'priority': priority,
        },
      );
      return CategoryTypeModel.fromMap(response.data);
    });
  }

  Future<CategoryModel> createCategory(String typeId, String name, String iconName, String color) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTableId,
        rowId: ID.unique(),
        data: {
          'categoryType': typeId,
          'name': name,
          'iconName': iconName,
          'color': color,
        },
      );
      return CategoryModel.fromMap(response.data);
    });
  }
}
