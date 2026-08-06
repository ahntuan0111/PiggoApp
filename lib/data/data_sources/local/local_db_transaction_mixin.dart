import 'dart:convert';
import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';
import 'package:appintern/data/models/transaction_model.dart';

mixin LocalDbTransactionMixin on LocalDatabaseBase {
  // ==========================================
  // TRANSACTIONS (SCALE-READY)
  // ==========================================
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

  // ==========================================
  // ROLLBACK (Compensating Transaction)
  // ==========================================
  Future<void> rollbackOptimisticTransaction(
    String type,
    String payload,
  ) async {
    final db = await database;
    try {
      if (type == 'CREATE_TRANSACTION' || type == 'MANUAL_TRANSACTION') {
        final Map<String, dynamic> data = jsonDecode(payload);
        final String? transactionId = data['id'];
        if (transactionId != null) {
          // Delete transaction locally
          await db.delete(
            'transactions',
            where: 'id = ?',
            whereArgs: [transactionId],
          );
        }
      } else if (type == 'CREATE_GOAL') {
        final Map<String, dynamic> data = jsonDecode(payload);
        final String? tempGoalId = data['goal']?['id'];
        final String? tempCatId = data['category']?['id'];
        if (tempGoalId != null) {
          await db.delete('goals', where: 'id = ?', whereArgs: [tempGoalId]);
        }
        if (tempCatId != null) {
          await db.delete('categories', where: 'id = ?', whereArgs: [tempCatId]);
        }
      } else if (type == 'UPDATE_GOAL') {
        // Optimistic rollback is more complex, typically we just fetch remote again
        // For now, no-op since offline update failures usually mean we should just sync down
      } else if (type == 'DELETE_GOAL') {
        // Rollback a delete means restoring it, which is hard without the full object
        // Usually handled by fetching again from Appwrite
      }
    } catch (e) {
      print("Rollback Error: $e");
    }
  }
}
