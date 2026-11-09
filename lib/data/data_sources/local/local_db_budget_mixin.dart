import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';
import 'package:appintern/core/utils/offline_helper.dart';

mixin LocalDbBudgetMixin on LocalDatabaseBase {
  // ==========================================
  // MONTHLY BUDGETS
  // ==========================================
  Future<void> saveMonthlyBudgets(
    String monthYear,
    List<Map<String, dynamic>> budgets, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    Batch batch = db.batch();

    // Purge logic: Xóa các budget cũ của tháng này thuộc user này trước khi lưu đè
    batch.delete(
      'monthly_budgets',
      where: 'monthYear = ? AND userId = ?',
      whereArgs: [monthYear, effectiveUserId],
    );

    for (var mb in budgets) {
      batch.insert('monthly_budgets', {
        'id': mb['id'],
        'userId': mb['userId'] ?? effectiveUserId,
        'categoryId': mb['categoryId'] ?? mb['categories'],
        'monthYear': mb['monthYear'],
        'budgetedAmount': mb['budgetedAmount'],
        'rolloverAmount': mb['rolloverAmount'],
        'spentAmount': mb['spentAmount'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMonthlyBudgets(
    String monthYear, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    return await db.query(
      'monthly_budgets',
      where: 'monthYear = ? AND userId = ?',
      whereArgs: [monthYear, effectiveUserId],
    );
  }

  Future<void> updateLocalBudgetSpent(
    String categoryId,
    String monthYear,
    double amountChange, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    final existing = await db.query(
      'monthly_budgets',
      where: 'categoryId = ? AND monthYear = ? AND userId = ?',
      whereArgs: [categoryId, monthYear, effectiveUserId],
    );
    if (existing.isNotEmpty) {
      double currentSpent = (existing.first['spentAmount'] as num).toDouble();
      double newSpent = currentSpent + amountChange;
      if (newSpent < 0) newSpent = 0;
      await db.update(
        'monthly_budgets',
        {'spentAmount': newSpent},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  Future<void> transferBudgetLocal(
    String? fromId,
    String? toId,
    double amount,
    String monthYear, {
    String? note,
    bool isOffline = true,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    await db.transaction((txn) async {
      // 1. Update fromId if provided (and not 'unallocated')
      if (fromId != null && fromId.isNotEmpty && fromId != 'unallocated') {
        final fromCatResult = await txn.query(
          'categories',
          where: 'id = ? AND userId = ?',
          whereArgs: [fromId, effectiveUserId],
        );
        if (fromCatResult.isNotEmpty) {
          double currentDefault =
              (fromCatResult.first['defaultBudget'] as num?)?.toDouble() ?? 0.0;
          double newDefault = currentDefault - amount;
          if (newDefault < 0) newDefault = 0;
          await txn.update(
            'categories',
            {'defaultBudget': newDefault},
            where: 'id = ? AND userId = ?',
            whereArgs: [fromId, effectiveUserId],
          );
        }

        final fromMbResult = await txn.query(
          'monthly_budgets',
          where: 'categoryId = ? AND monthYear = ? AND userId = ?',
          whereArgs: [fromId, monthYear, effectiveUserId],
        );
        if (fromMbResult.isNotEmpty) {
          double currentBudgeted =
              (fromMbResult.first['budgetedAmount'] as num?)?.toDouble() ?? 0.0;
          double newBudgeted = currentBudgeted - amount;
          if (newBudgeted < 0) newBudgeted = 0;
          await txn.update(
            'monthly_budgets',
            {'budgetedAmount': newBudgeted},
            where: 'id = ?',
            whereArgs: [fromMbResult.first['id']],
          );
        } else {
          await txn.insert('monthly_budgets', {
            'id': OfflineHelper.generateTempId(fromId),
            'userId': effectiveUserId,
            'categoryId': fromId,
            'monthYear': monthYear,
            'budgetedAmount': 0.0,
            'rolloverAmount': 0.0,
            'spentAmount': 0.0,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      } else if (fromId == 'unallocated') {
        final summaryResult = await txn.query(
          'monthly_summaries',
          where: 'monthYear = ? AND userId = ?',
          whereArgs: [monthYear, effectiveUserId],
        );
        if (summaryResult.isNotEmpty) {
          double currentUnallocated =
              (summaryResult.first['unallocatedBalance'] as num?)?.toDouble() ?? 0.0;
          double newUnallocated = currentUnallocated - amount;
          await txn.update(
            'monthly_summaries',
            {'unallocatedBalance': newUnallocated},
            where: 'id = ?',
            whereArgs: [summaryResult.first['id']],
          );
        }
      }

      // 2. Update toId
      if (toId != null && toId.isNotEmpty && toId != 'unallocated') {
        final toCatResult = await txn.query(
          'categories',
          where: 'id = ? AND userId = ?',
          whereArgs: [toId, effectiveUserId],
        );
        if (toCatResult.isNotEmpty) {
          double currentDefault =
              (toCatResult.first['defaultBudget'] as num?)?.toDouble() ?? 0.0;
          double newDefault = currentDefault + amount;
          await txn.update(
            'categories',
            {'defaultBudget': newDefault},
            where: 'id = ? AND userId = ?',
            whereArgs: [toId, effectiveUserId],
          );
        }

        final toMbResult = await txn.query(
          'monthly_budgets',
          where: 'categoryId = ? AND monthYear = ? AND userId = ?',
          whereArgs: [toId, monthYear, effectiveUserId],
        );
        if (toMbResult.isNotEmpty) {
          double currentBudgeted =
              (toMbResult.first['budgetedAmount'] as num?)?.toDouble() ?? 0.0;
          double newBudgeted = currentBudgeted + amount;
          await txn.update(
            'monthly_budgets',
            {'budgetedAmount': newBudgeted},
            where: 'id = ?',
            whereArgs: [toMbResult.first['id']],
          );
        } else {
          await txn.insert('monthly_budgets', {
            'id': OfflineHelper.generateTempId(toId),
            'userId': effectiveUserId,
            'categoryId': toId,
            'monthYear': monthYear,
            'budgetedAmount': amount,
            'rolloverAmount': 0.0,
            'spentAmount': 0.0,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      } else if (toId == 'unallocated') {
        final summaryResult = await txn.query(
          'monthly_summaries',
          where: 'monthYear = ? AND userId = ?',
          whereArgs: [monthYear, effectiveUserId],
        );
        if (summaryResult.isNotEmpty) {
          double currentUnallocated =
              (summaryResult.first['unallocatedBalance'] as num?)?.toDouble() ?? 0.0;
          double newUnallocated = currentUnallocated + amount;
          await txn.update(
            'monthly_summaries',
            {'unallocatedBalance': newUnallocated},
            where: 'id = ?',
            whereArgs: [summaryResult.first['id']],
          );
        } else {
          await txn.insert('monthly_summaries', {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'userId': effectiveUserId,
            'monthYear': monthYear,
            'totalIncome': 0.0,
            'totalExpense': 0.0,
            'unallocatedBalance': amount,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      }

      // 3. Insert into transfer_logs
      if (amount > 0) {
        final logId = OfflineHelper.generateTempId(
          '${fromId ?? "unallocated"}_${toId ?? "unallocated"}',
        );
        final logMap = {
          'id': logId,
          'userId': effectiveUserId,
          'amount': amount,
          'fromCategoryId': fromId ?? '',
          'toCategoryId': toId ?? '',
          'note': note ?? 'Cân bằng ngân sách',
          'createdAt': DateTime.now().toIso8601String(),
        };
        await txn.insert('transfer_logs', logMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ==========================================
  // MONTHLY SUMMARIES
  // ==========================================
  Future<void> saveMonthlySummaries(
    List<Map<String, dynamic>> summaries, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    Batch batch = db.batch();

    // Purge logic: Xóa các records của user này trước khi lưu mới
    batch.delete(
      'monthly_summaries',
      where: 'userId = ?',
      whereArgs: [effectiveUserId],
    );

    for (var ms in summaries) {
      batch.insert('monthly_summaries', {
        'id': ms['id'],
        'userId': ms['userId'] ?? effectiveUserId,
        'monthYear': ms['monthYear'],
        'totalIncome': ms['totalIncome'],
        'totalExpense': ms['totalExpense'],
        'unallocatedBalance': ms['unallocatedBalance'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMonthlySummaries({
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    return await db.query(
      'monthly_summaries',
      where: 'userId = ?',
      whereArgs: [effectiveUserId],
    );
  }

  Future<void> updateLocalSummary(
    String monthYear,
    double incomeChange,
    double expenseChange, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    final existing = await db.query(
      'monthly_summaries',
      where: 'monthYear = ? AND userId = ?',
      whereArgs: [monthYear, effectiveUserId],
    );
    if (existing.isNotEmpty) {
      double currentIncome = (existing.first['totalIncome'] as num).toDouble();
      double currentExpense = (existing.first['totalExpense'] as num)
          .toDouble();

      double newIncome = currentIncome + incomeChange;
      double newExpense = currentExpense + expenseChange;

      if (newIncome < 0) newIncome = 0;
      if (newExpense < 0) newExpense = 0;

      await db.update(
        'monthly_summaries',
        {'totalIncome': newIncome, 'totalExpense': newExpense},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('monthly_summaries', {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': effectiveUserId,
        'monthYear': monthYear,
        'totalIncome': incomeChange > 0 ? incomeChange : 0,
        'totalExpense': expenseChange > 0 ? expenseChange : 0,
        'unallocatedBalance': 0.0,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getTransferLogsByCategoryId(
    String categoryId, {
    int limit = 5,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    try {
      return await db.query(
        'transfer_logs',
        where: 'userId = ? AND (fromCategoryId = ? OR toCategoryId = ?)',
        whereArgs: [effectiveUserId, categoryId, categoryId],
        orderBy: 'createdAt DESC',
        limit: limit,
      );
    } catch (_) {
      return [];
    }
  }

  // ==========================================
  // MONTHLY CATEGORY SUMMARIES (RETENTION ARCHIVE)
  // ==========================================
  Future<void> saveMonthlyCategorySummaries(
    List<Map<String, dynamic>> items, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    final batch = db.batch();
    for (var item in items) {
      batch.insert(
        'monthly_category_summaries',
        {
          'id': item['id'] ??
              'mcs_${effectiveUserId}_${item['categoryId']}_${item['monthYear']}',
          'userId': item['userId'] ?? effectiveUserId,
          'monthYear': item['monthYear'],
          'categoryId': item['categoryId'],
          'categoryName': item['categoryName'] ?? 'Khác',
          'categoryColor': item['categoryColor'] ?? '#9E9E9E',
          'categoryIcon': item['categoryIcon'] ?? 'icon_wallet.png',
          'totalExpense': (item['totalExpense'] as num?)?.toDouble() ?? 0.0,
          'totalIncome': (item['totalIncome'] as num?)?.toDouble() ?? 0.0,
          'transactionCount': (item['transactionCount'] as num?)?.toInt() ?? 0,
          'createdAt': item['createdAt'] ?? DateTime.now().toIso8601String(),
          'updatedAt': item['updatedAt'] ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMonthlyCategorySummaries(
    String monthYear, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    return await db.query(
      'monthly_category_summaries',
      where: 'monthYear = ? AND userId = ?',
      whereArgs: [monthYear, effectiveUserId],
    );
  }

  Future<List<Map<String, dynamic>>> getMonthlyCategorySummariesForRange(
    List<String> monthYears, {
    String? userId,
  }) async {
    if (monthYears.isEmpty) return [];
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    final placeholders = List.filled(monthYears.length, '?').join(',');
    return await db.query(
      'monthly_category_summaries',
      where: 'userId = ? AND monthYear IN ($placeholders)',
      whereArgs: [effectiveUserId, ...monthYears],
    );
  }

  Future<List<Map<String, dynamic>>> getMonthlyCategorySummariesByCategoryId(
    String categoryId,
    List<String> monthYears, {
    String? userId,
  }) async {
    if (monthYears.isEmpty) return [];
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    final placeholders = List.filled(monthYears.length, '?').join(',');
    return await db.query(
      'monthly_category_summaries',
      where: 'userId = ? AND categoryId = ? AND monthYear IN ($placeholders)',
      whereArgs: [effectiveUserId, categoryId, ...monthYears],
    );
  }
}
