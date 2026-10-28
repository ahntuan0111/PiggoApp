import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/data/models/monthly_budget_model.dart';
import 'package:appintern/data/models/monthly_summary_model.dart';
import 'package:get/get.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/core/utils/offline_helper.dart';
import 'package:sqflite/sqflite.dart';

class CategoryRepository {
  CategoryRepository();

  Future<void> createDefaultCategoryTypes([String? userId]) async {
    final localDb = Get.find<LocalDatabaseService>();
    final defaultTypes = [
      {'id': 'ct_fixed', 'name': 'Cố định', 'priority': 1},
      {'id': 'ct_essential', 'name': 'Thiết yếu', 'priority': 2},
      {'id': 'ct_saving', 'name': 'Tiết kiệm', 'priority': 3},
    ];
    await localDb.saveCategoryTypes(defaultTypes);
  }

  Future<List<CategoryTypeModel>> getCategoryTypes([String? userId]) async {
    final localDb = Get.find<LocalDatabaseService>();
    final types = await localDb.getCategoryTypes();
    return types.map((e) => CategoryTypeModel.fromMap(e)).toList();
  }

  Future<CategoryTypeModel> getOrCreateSavingCategoryType([String? userId]) async {
    final types = await getCategoryTypes(userId);
    final existing = types.firstWhereOrNull((t) => t.name == 'Tiết kiệm lâu dài');
    if (existing != null) {
      return existing;
    }
    return await createCategoryType(userId ?? '', 'Tiết kiệm lâu dài', 99);
  }

  Future<CategoryTypeModel> createCategoryType(
    String userId,
    String name,
    int priority,
  ) async {
    final localDb = Get.find<LocalDatabaseService>();
    final id = 'ct_${DateTime.now().millisecondsSinceEpoch}';
    await localDb.insertCategoryType(
      {'id': id, 'name': name, 'priority': priority},
    );
    return CategoryTypeModel(id: id, name: name, priority: priority);
  }

  Future<CategoryTypeModel> updateCategoryType(
    String typeId,
    String name,
  ) async {
    final localDb = Get.find<LocalDatabaseService>();
    await localDb.updateCategoryType(typeId, name);
    return CategoryTypeModel(id: typeId, name: name, priority: 0);
  }

  Future<void> deleteCategoryType(String typeId) async {
    final localDb = Get.find<LocalDatabaseService>();
    await localDb.deleteCategoryType(typeId);
  }

  Future<List<CategoryModel>> getCategories([List<String>? typeIds]) async {
    final localDb = Get.find<LocalDatabaseService>();
    final rows = await localDb.getCategories();
    var list = rows.map((e) => CategoryModel.fromMap(e)).toList();
    if (typeIds != null) {
      if (typeIds.isEmpty) return [];
      list = list.where((c) => typeIds.contains(c.categoryTypeId)).toList();
    }
    return list;
  }

  Future<CategoryModel> createCategory(
    String typeId,
    String name,
    String iconName,
    String color, {
    bool isActive = true,
    String? userId,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    final cat = CategoryModel(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      categoryTypeId: typeId,
      name: name,
      iconName: iconName,
      color: color,
      isActive: isActive,
    );
    await localDb.insertLocalCategory(cat.toMap());
    return cat;
  }

  Future<CategoryModel> updateCategory(
    String categoryId,
    String name,
    String iconName,
    String color, {
    double? defaultBudget,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    await localDb.updateCategory(categoryId, name, iconName, color);
    if (defaultBudget != null) {
      final db = await localDb.database;
      await db.update(
        'categories',
        {'defaultBudget': defaultBudget},
        where: 'id = ?',
        whereArgs: [categoryId],
      );
    }
    final all = await localDb.getCategories();
    final row = all.firstWhereOrNull((c) => c['id'] == categoryId);
    if (row != null) {
      return CategoryModel.fromMap(row);
    }
    return CategoryModel(
      id: categoryId,
      categoryTypeId: '',
      name: name,
      iconName: iconName,
      color: color,
      defaultBudget: defaultBudget ?? 0.0,
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    final localDb = Get.find<LocalDatabaseService>();
    await localDb.deleteCategory(categoryId);
  }

  Future<List<MonthlyBudgetModel>> getMonthlyBudgets(
    String monthYearStr, {
    List<String>? categoryIds,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    final rows = await localDb.getMonthlyBudgets(monthYearStr);
    var list = rows
        .map((doc) => MonthlyBudgetModel.fromMap(doc))
        .where((mb) => mb.categoryId.isNotEmpty)
        .toList();
    if (categoryIds != null) {
      if (categoryIds.isEmpty) return [];
      list = list.where((mb) => categoryIds.contains(mb.categoryId)).toList();
    }
    return list;
  }

  Future<List<MonthlySummaryModel>> getAllMonthlySummaries() async {
    final localDb = Get.find<LocalDatabaseService>();
    final rows = await localDb.getMonthlySummaries();
    return rows.map((doc) => MonthlySummaryModel.fromMap(doc)).toList();
  }

  Future<void> updateMonthlyBudget(
    String budgetId,
    double budgetedAmount,
  ) async {
    final localDb = Get.find<LocalDatabaseService>();
    final db = await localDb.database;
    await db.update(
      'monthly_budgets',
      {
        'budgetedAmount': budgetedAmount,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [budgetId],
    );
  }

  Future<MonthlyBudgetModel> createMonthlyBudget({
    required String categoryId,
    required String monthYear,
    required double budgetedAmount,
    double rolloverAmount = 0.0,
    double spentAmount = 0.0,
    String? userId,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    final db = await localDb.database;
    final nowStr = DateTime.now().toIso8601String();
    final id = 'mb_${categoryId}_$monthYear';
    final model = MonthlyBudgetModel(
      id: id,
      categoryId: categoryId,
      monthYear: monthYear,
      budgetedAmount: budgetedAmount,
      rolloverAmount: rolloverAmount,
      spentAmount: spentAmount,
    );
    await db.insert(
      'monthly_budgets',
      {
        'id': id,
        'categoryId': categoryId,
        'monthYear': monthYear,
        'budgetedAmount': budgetedAmount,
        'rolloverAmount': rolloverAmount,
        'spentAmount': spentAmount,
        'createdAt': nowStr,
        'updatedAt': nowStr,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return model;
  }

  Future<void> transferBudget(
    String monthYear,
    List<Map<String, dynamic>> allocations, {
    List<Map<String, dynamic>>? transferLogs,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    final db = await localDb.database;
    await db.transaction((txn) async {
      for (final alloc in allocations) {
        final categoryId = alloc['categoryId'] as String;
        final amount = (alloc['amount'] as num).toDouble();

        // 1. Cập nhật Category defaultBudget
        await txn.update(
          'categories',
          {'defaultBudget': amount},
          where: 'id = ?',
          whereArgs: [categoryId],
        );

        // 2. Cập nhật Monthly Budget
        final existingMb = await txn.query(
          'monthly_budgets',
          where: 'categoryId = ? AND monthYear = ?',
          whereArgs: [categoryId, monthYear],
        );

        if (existingMb.isNotEmpty) {
          await txn.update(
            'monthly_budgets',
            {'budgetedAmount': amount},
            where: 'id = ?',
            whereArgs: [existingMb.first['id']],
          );
        } else {
          await txn.insert('monthly_budgets', {
            'id': OfflineHelper.generateTempId(categoryId),
            'categoryId': categoryId,
            'monthYear': monthYear,
            'budgetedAmount': amount,
            'rolloverAmount': 0.0,
            'spentAmount': 0.0,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      }

      // 3. Ghi log chuyển quỹ
      if (transferLogs != null && transferLogs.isNotEmpty) {
        for (final logItem in transferLogs) {
          final logMap = {
            'id': OfflineHelper.generateTempId('translog'),
            'amount': (logItem['amount'] as num).toDouble(),
            'fromCategoryId': logItem['fromCategoryId'] ?? '',
            'toCategoryId': logItem['toCategoryId'] ?? '',
            'note': logItem['note'] ?? '',
            'createdAt': DateTime.now().toIso8601String(),
          };
          await txn.insert(
            'transfer_logs',
            logMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
