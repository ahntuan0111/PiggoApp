import 'dart:convert';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/data/models/monthly_budget_model.dart';
import 'package:appintern/data/models/monthly_summary_model.dart';
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
        await _appwrite.databases.createDocument(
          databaseId: _appwrite.databaseId,
          collectionId: _appwrite.categoriesTypeTableId,
          documentId: ID.unique(),
          data: {
            'name': type['name'],
            'priority': type['priority'],
          },
        );
      }
    });
  }

  Future<List<CategoryTypeModel>> getCategoryTypes(String userId) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTypeTableId,
        queries: [Query.orderAsc('priority')],
      );
      return response.documents
          .map(
            (doc) => CategoryTypeModel.fromMap(
              Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
            ),
          )
          .toList();
    });
  }

  Future<CategoryTypeModel> getOrCreateSavingCategoryType(String userId) async {
    return handleAppwriteError(() async {
      final typeResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTypeTableId,
        queries: [
          Query.equal('name', 'Tiết kiệm lâu dài'),
        ],
      );
      if (typeResponse.documents.isNotEmpty) {
        return CategoryTypeModel.fromMap(
          Map<String, dynamic>.from(typeResponse.documents.first.data)
            ..['\$id'] = typeResponse.documents.first.$id,
        );
      } else {
        final newTypeResponse = await _appwrite.databases.createDocument(
          databaseId: _appwrite.databaseId,
          collectionId: _appwrite.categoriesTypeTableId,
          documentId: ID.unique(),
          data: {
            'name': 'Tiết kiệm lâu dài',
            'priority': 99,
          },
        );
        return CategoryTypeModel.fromMap(
          Map<String, dynamic>.from(newTypeResponse.data)
            ..['\$id'] = newTypeResponse.$id,
        );
      }
    });
  }

  Future<List<CategoryModel>> getCategories(List<String> typeIds) async {
    if (typeIds.isEmpty) return [];
    return handleAppwriteError(() async {
      List<CategoryModel> allCategories = [];

      for (String typeId in typeIds) {
        final response = await _appwrite.databases.listDocuments(
          databaseId: _appwrite.databaseId,
          collectionId: _appwrite.categoriesTableId,
          queries: [Query.equal('categoryTypes', typeId)],
        );

        for (var doc in response.documents) {
          CategoryModel cat = CategoryModel.fromMap(
            Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
          );
          allCategories.add(cat);
        }
      }
      return allCategories;
    });
  }

  Future<List<MonthlyBudgetModel>> getMonthlyBudgets(
    String monthYearStr,
  ) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.equal('monthYear', monthYearStr)],
      );
      return response.documents
          .map(
            (doc) => MonthlyBudgetModel.fromMap(
              Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
            ),
          )
          .where((mb) => mb.categoryId.isNotEmpty)
          .toList();
    });
  }

  Future<List<MonthlySummaryModel>> getAllMonthlySummaries() async {
    return handleAppwriteError(() async {
      final response = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlySummariesTableId,
      );
      return response.documents
          .map(
            (doc) => MonthlySummaryModel.fromMap(
              Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
            ),
          )
          .toList();
    });
  }

  Future<CategoryTypeModel> createCategoryType(
    String userId,
    String name,
    int priority,
  ) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.databases.createDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTypeTableId,
        documentId: ID.unique(),
        data: {'name': name, 'priority': priority},
      );
      return CategoryTypeModel.fromMap(
        Map<String, dynamic>.from(response.data)..['\$id'] = response.$id,
      );
    });
  }

  Future<CategoryModel> createCategory(
    String typeId,
    String name,
    String iconName,
    String color, {
    bool isActive = true,
  }) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.databases.createDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTableId,
        documentId: ID.unique(),
        data: {
          'categoryTypes': typeId,
          'name': name,
          'iconName': iconName,
          'color': color,
          'isActive': isActive,
        },
      );
      return CategoryModel.fromMap(
        Map<String, dynamic>.from(response.data)..['\$id'] = response.$id,
      );
    });
  }

  Future<CategoryTypeModel> updateCategoryType(
    String typeId,
    String name,
  ) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.databases.updateDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTypeTableId,
        documentId: typeId,
        data: {'name': name},
      );
      return CategoryTypeModel.fromMap(
        Map<String, dynamic>.from(response.data)..['\$id'] = response.$id,
      );
    });
  }

  Future<void> deleteCategoryType(String typeId) async {
    return handleAppwriteError(() async {
      await _appwrite.databases.deleteDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTypeTableId,
        documentId: typeId,
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
      final response = await _appwrite.databases.updateDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTableId,
        documentId: categoryId,
        data: data,
      );
      return CategoryModel.fromMap(
        Map<String, dynamic>.from(response.data)..['\$id'] = response.$id,
      );
    });
  }

  Future<void> updateMonthlyBudget(
    String budgetId,
    double budgetedAmount,
  ) async {
    return handleAppwriteError(() async {
      await _appwrite.databases.updateDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlyBudgetsTableId,
        documentId: budgetId,
        data: {'budgetedAmount': budgetedAmount},
      );
    });
  }

  Future<MonthlyBudgetModel> createMonthlyBudget({
    required String categoryId,
    required String monthYear,
    required double budgetedAmount,
    double rolloverAmount = 0.0,
    double spentAmount = 0.0,
  }) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.databases.createDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlyBudgetsTableId,
        documentId: ID.unique(),
        data: {
          'categories': categoryId,
          'monthYear': monthYear,
          'budgetedAmount': budgetedAmount,
          'rolloverAmount': rolloverAmount,
          'spentAmount': spentAmount,
        },
      );
      return MonthlyBudgetModel.fromMap(
        Map<String, dynamic>.from(response.data)..['\$id'] = response.$id,
      );
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    return handleAppwriteError(() async {
      // 1. Tìm tất cả các giao dịch liên kết với danh mục này và ngắt liên kết (categories = null)
      final txResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.transactionsTableId,
        queries: [Query.equal('categories', categoryId)],
      );

      for (var doc in txResponse.documents) {
        await _appwrite.databases.updateDocument(
          databaseId: _appwrite.databaseId,
          collectionId: _appwrite.transactionsTableId,
          documentId: doc.$id,
          data: {'categories': null},
        );
      }

      // 2. Tìm tất cả MonthlyBudget liên kết với danh mục này và xóa chúng
      final budgetResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.equal('categories', categoryId)],
      );

      for (var doc in budgetResponse.documents) {
        await _appwrite.databases.deleteDocument(
          databaseId: _appwrite.databaseId,
          collectionId: _appwrite.monthlyBudgetsTableId,
          documentId: doc.$id,
        );
      }

      // 3. Xóa danh mục
      await _appwrite.databases.deleteDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTableId,
        documentId: categoryId,
      );
    });
  }

  Future<void> transferBudget(
    String monthYear,
    List<Map<String, dynamic>> allocations, {
    List<Map<String, dynamic>>? transferLogs,
  }) async {
    return handleAppwriteError(() async {
      final payload = {
        'monthYear': monthYear,
        'allocations': allocations,
        if (transferLogs != null) 'transferLogs': transferLogs,
      };

      await _appwrite.functions.createExecution(
        functionId: _appwrite.functionTransferBudget,
        body: jsonEncode(payload),
        xasync: false,
      );
    });
  }
}
