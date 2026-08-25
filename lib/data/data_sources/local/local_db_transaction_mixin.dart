import 'dart:convert';
import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';
import 'package:appintern/data/models/transaction_model.dart';

mixin LocalDbTransactionMixin on LocalDatabaseBase {
  Future<void> saveTransactions(List<TransactionModel> txs) async {
    final db = await database;
    Batch batch = db.batch();
    for (var tx in txs) {
      batch.insert('transactions', {
        'id': tx.id,
        'categoryId': tx.categoryId,
        'amount': tx.amount,
        'type': tx.type,
        'transactionDate': tx.transactionDate.toIso8601String(),
        'status': tx.status,
        'note': tx.note ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<bool> hasAnyTransactions() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM transactions'));
    return (count ?? 0) > 0;
  }

  Future<List<TransactionModel>> getTransactionsByMonth(
    String monthYearStr,
  ) async {
    final db = await database;
    // monthYearStr có định dạng MM-YYYY
    final parts = monthYearStr.split('-');
    if (parts.length != 2) return [];

    final year = parts[1];
    final month = parts[0].padLeft(2, '0');
    final startPrefix = '$year-$month-'; // Ví dụ: 2026-07-

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'transactionDate LIKE ?',
      whereArgs: ['$startPrefix%'],
      orderBy: 'transactionDate DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel(
        id: maps[i]['id'] as String,
        categoryId: maps[i]['categoryId'] as String,
        amount: maps[i]['amount'] as double,
        type: maps[i]['type'] as String,
        transactionDate: DateTime.parse(maps[i]['transactionDate'] as String),
        status: maps[i]['status'] as String,
        note: maps[i]['note'] as String?,
      );
    });
  }

  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'transactionDate >= ? AND transactionDate <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'transactionDate DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel(
        id: maps[i]['id'] as String,
        categoryId: maps[i]['categoryId'] as String,
        amount: maps[i]['amount'] as double,
        type: maps[i]['type'] as String,
        transactionDate: DateTime.parse(maps[i]['transactionDate'] as String),
        status: maps[i]['status'] as String,
        note: maps[i]['note'] as String?,
      );
    });
  }

  Future<TransactionModel?> getTransactionById(String transactionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TransactionModel(
      id: maps[0]['id'] as String,
      categoryId: maps[0]['categoryId'] as String,
      amount: maps[0]['amount'] as double,
      type: maps[0]['type'] as String,
      transactionDate: DateTime.parse(maps[0]['transactionDate'] as String),
      status: maps[0]['status'] as String,
      note: maps[0]['note'] as String?,
    );
  }

  Future<void> rollbackOptimisticTransaction(
    String type,
    String payload,
  ) async {
    final db = await database;
    try {
      final Map<String, dynamic> data = jsonDecode(payload);

      if (type == 'CREATE_MANUAL_TX' || type == 'CREATE_WALLET_ADJUSTMENT') {
        // Rollback: Xóa giao dịch tạm + hoàn tác số dư local
        final txData = data['transaction'];
        if (txData != null) {
          final String? tempId = txData['\$id'] ?? txData['id'];
          final String? categoryId = txData['categoryId'];
          final double amount = (txData['amount'] as num?)?.toDouble() ?? 0.0;
          final String txType = txData['type'] ?? 'EXPENSE';

          // Xóa giao dịch tạm khỏi local DB
          if (tempId != null) {
            await db.delete(
              'transactions',
              where: 'id = ?',
              whereArgs: [tempId],
            );
          }

          // Hoàn tác budget spent cho category
          if (categoryId != null && categoryId.isNotEmpty) {
            final txDateStr = txData['transactionDate'];
            final txDate = txDateStr != null
                ? DateTime.tryParse(txDateStr) ?? DateTime.now()
                : DateTime.now();
            final monthYear =
                "${txDate.month.toString().padLeft(2, '0')}-${txDate.year}";

            if (type == 'CREATE_MANUAL_TX') {
              // Hoàn tác: giảm spentAmount đã cộng lúc optimistic
              await _revertBudgetSpent(db, categoryId, monthYear, amount);
            }
          }

          // Hoàn tác monthly summary
          if (amount > 0) {
            final txDateStr = txData['transactionDate'];
            final txDate = txDateStr != null
                ? DateTime.tryParse(txDateStr) ?? DateTime.now()
                : DateTime.now();
            final monthYear =
                "${txDate.month.toString().padLeft(2, '0')}-${txDate.year}";

            if (txType == 'INCOME') {
              await _revertSummary(db, monthYear, -amount, 0);
            } else {
              await _revertSummary(db, monthYear, 0, -amount);
            }
          }
        }
      } else if (type == 'CREATE_GOAL') {
        final goalData = data['goal'];
        final String? tempGoalId = goalData?['id'];
        final String? tempCatId = goalData?['categoryId'];
        if (tempGoalId != null) {
          await db.delete('goals', where: 'id = ?', whereArgs: [tempGoalId]);
        }
        if (tempCatId != null) {
          await db.delete(
            'categories',
            where: 'id = ?',
            whereArgs: [tempCatId],
          );
        }
      } else if (type == 'CREATE_CATEGORY_TYPE') {
        final String? tempId = data['tempId'];
        if (tempId != null) {
          await db.delete(
            'category_types',
            where: 'id = ?',
            whereArgs: [tempId],
          );
        }
      } else if (type == 'CREATE_CATEGORY') {
        final String? tempId = data['tempId'];
        if (tempId != null) {
          await db.delete('categories', where: 'id = ?', whereArgs: [tempId]);
        }
      }
      // UPDATE/DELETE types: không cần rollback phức tạp,
      // BudgetService.refreshData() sẽ sync lại từ server khi có mạng
    } catch (e) {
      // Rollback lỗi không nên crash app — chỉ log
      print("Rollback Error for task type '$type': $e");
    }
  }

  /// Hoàn tác spentAmount đã cộng optimistically
  Future<void> _revertBudgetSpent(
    Database db,
    String categoryId,
    String monthYear,
    double amount,
  ) async {
    final existing = await db.query(
      'monthly_budgets',
      where: 'categoryId = ? AND monthYear = ?',
      whereArgs: [categoryId, monthYear],
    );
    if (existing.isNotEmpty) {
      double currentSpent = (existing.first['spentAmount'] as num).toDouble();
      double newSpent = currentSpent - amount;
      if (newSpent < 0) newSpent = 0;
      await db.update(
        'monthly_budgets',
        {'spentAmount': newSpent},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  /// Hoàn tác monthly summary đã cộng optimistically
  Future<void> _revertSummary(
    Database db,
    String monthYear,
    double incomeChange,
    double expenseChange,
  ) async {
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
    }
  }
}
