import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';
import 'package:appintern/core/utils/offline_helper.dart';

mixin LocalDbBudgetMixin on LocalDatabaseBase {
  // ==========================================
  // MONTHLY BUDGETS
  // ==========================================
  Future<void> saveMonthlyBudgets(
    String monthYear,
    List<Map<String, dynamic>> budgets,
  ) async {
    final db = await database;
    Batch batch = db.batch();

    // Purge logic: Xóa các budget cũ của tháng này trước khi lưu đè
    batch.delete(
      'monthly_budgets',
      where: 'monthYear = ?',
      whereArgs: [monthYear],
    );

    for (var mb in budgets) {
      batch.insert('monthly_budgets', {
        'id': mb['id'],
        'categoryId': mb['categories'] ?? mb['categoryId'],
        'monthYear': mb['monthYear'],
        'budgetedAmount': mb['budgetedAmount'],
        'rolloverAmount': mb['rolloverAmount'],
        'spentAmount': mb['spentAmount'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMonthlyBudgets(String monthYear) async {
    final db = await database;
    return await db.query(
      'monthly_budgets',
      where: 'monthYear = ?',
      whereArgs: [monthYear],
    );
  }

  Future<void> updateLocalBudgetSpent(
    String categoryId,
    String monthYear,
    double amountChange,
  ) async {
    final db = await database;
    final existing = await db.query(
      'monthly_budgets',
      where: 'categoryId = ? AND monthYear = ?',
      whereArgs: [categoryId, monthYear],
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
    bool isOffline = true,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Update fromId if provided (and not 'unallocated')
      if (fromId != null && fromId != 'unallocated') {
        final fromCatResult = await txn.query(
          'categories',
          where: 'id = ?',
          whereArgs: [fromId],
        );
        if (fromCatResult.isNotEmpty) {
          double currentDefault =
              (fromCatResult.first['defaultBudget'] as num?)?.toDouble() ?? 0.0;
          double newDefault = currentDefault - amount;
          if (newDefault < 0) newDefault = 0;
          await txn.update(
            'categories',
            {'defaultBudget': newDefault},
            where: 'id = ?',
            whereArgs: [fromId],
          );
        }

        final fromMbResult = await txn.query(
          'monthly_budgets',
          where: 'categoryId = ? AND monthYear = ?',
          whereArgs: [fromId, monthYear],
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
            'id': OfflineHelper.generateTempId(fromId!),
            'categoryId': fromId,
            'monthYear': monthYear,
            'budgetedAmount': 0.0,
            'rolloverAmount': 0.0,
            'spentAmount': 0.0,
          });
        }
      }

      // 2. Update toId
      if (toId != null && toId != 'unallocated') {
        final toCatResult = await txn.query(
          'categories',
          where: 'id = ?',
          whereArgs: [toId],
        );
        if (toCatResult.isNotEmpty) {
          double currentDefault =
              (toCatResult.first['defaultBudget'] as num?)?.toDouble() ?? 0.0;
          double newDefault = currentDefault + amount;
          await txn.update(
            'categories',
            {'defaultBudget': newDefault},
            where: 'id = ?',
            whereArgs: [toId],
          );
        }

        final toMbResult = await txn.query(
          'monthly_budgets',
          where: 'categoryId = ? AND monthYear = ?',
          whereArgs: [toId, monthYear],
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
            'id': OfflineHelper.generateTempId(toId!),
            'categoryId': toId,
            'monthYear': monthYear,
            'budgetedAmount': amount,
            'rolloverAmount': 0.0,
            'spentAmount': 0.0,
          });
        }
      }

      // 3. Insert into transferlogs
      if (amount > 0) {
        await txn.insert('transferlogs', {
          'id': OfflineHelper.generateTempId(
            '${fromId ?? "unallocated"}_${toId ?? "unallocated"}',
          ),
          'ownerId': '', // Will be set on server or ignored locally
          'amount': amount,
          'fromCategoryId': fromId ?? '',
          'toCategoryId': toId ?? '',
          'note': 'Cân bằng ngân sách',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  // ==========================================
  // MONTHLY SUMMARIES
  // ==========================================
  Future<void> saveMonthlySummaries(
    List<Map<String, dynamic>> summaries,
  ) async {
    final db = await database;
    Batch batch = db.batch();

    // Purge logic: Xóa sạch bảng trước khi lưu mới (vì ta luôn fetch toàn bộ)
    batch.delete('monthly_summaries');

    for (var ms in summaries) {
      batch.insert('monthly_summaries', {
        'id': ms['id'],
        'monthYear': ms['monthYear'],
        'totalIncome': ms['totalIncome'],
        'totalExpense': ms['totalExpense'],
        'unallocatedBalance': ms['unallocatedBalance'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMonthlySummaries() async {
    final db = await database;
    return await db.query('monthly_summaries');
  }

  Future<void> updateLocalSummary(
    String monthYear,
    double incomeChange,
    double expenseChange,
  ) async {
    final db = await database;
    final existing = await db.query(
      'monthly_summaries',
      where: 'monthYear = ?',
      whereArgs: [monthYear],
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
  }) async {
    final db = await database;
    return await db.query(
      'transferlogs',
      where: 'fromCategoryId = ? OR toCategoryId = ?',
      whereArgs: [categoryId, categoryId],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
  }
}
