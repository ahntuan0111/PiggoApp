import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';

mixin LocalDbBudgetMixin on LocalDatabaseBase {
  // ==========================================
  // MONTHLY BUDGETS
  // ==========================================
  Future<void> saveMonthlyBudgets(String monthYear, List<Map<String, dynamic>> budgets) async {
    final db = await database;
    Batch batch = db.batch();
    
    // Purge logic: Xóa các budget cũ của tháng này trước khi lưu đè
    batch.delete('monthly_budgets', where: 'monthYear = ?', whereArgs: [monthYear]);
    
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
}
