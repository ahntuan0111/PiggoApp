import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';

mixin LocalDbTransactionMixin on LocalDatabaseBase {
  Future<void> saveTransactions(List<TransactionModel> txs) async {
    final db = await database;
    Batch batch = db.batch();
    for (var tx in txs) {
      final String? safeCategoryId =
          (tx.categoryId.isEmpty || tx.categoryId == 'SYSTEM_ROLLOVER')
              ? null
              : tx.categoryId;
      batch.insert('transactions', {
        'id': tx.id,
        'categoryId': safeCategoryId,
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

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'transactionDate DESC',
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
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
        categoryId: (maps[i]['categoryId'] as String?) ?? '',
        amount: (maps[i]['amount'] as num).toDouble(),
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
        categoryId: (maps[i]['categoryId'] as String?) ?? '',
        amount: (maps[i]['amount'] as num).toDouble(),
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
      categoryId: (maps[0]['categoryId'] as String?) ?? '',
      amount: (maps[0]['amount'] as num).toDouble(),
      type: maps[0]['type'] as String,
      transactionDate: DateTime.parse(maps[0]['transactionDate'] as String),
      status: maps[0]['status'] as String,
      note: maps[0]['note'] as String?,
    );
  }



  // =========================================================================
  // ATOMIC SQLITE TRANSACTIONS (GIAI ĐOẠN 1 MIGRATION)
  // =========================================================================

  /// Ghi nguyên tử giao dịch, chi tiết biên lai, cập nhật ngân sách và báo cáo tháng
  Future<void> insertTransactionAtomic(
    TransactionModel tx, {
    TransactionDetailModel? detail,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await _insertTransactionWithTxn(txn, tx, detail: detail);
    });
  }

  /// Helper thực thi ghi nguyên tử giao dịch trong một transaction có sẵn
  Future<void> _insertTransactionWithTxn(
    DatabaseExecutor txn,
    TransactionModel tx, {
    TransactionDetailModel? detail,
  }) async {
    final nowStr = DateTime.now().toIso8601String();
    final String? safeCategoryId =
        (tx.categoryId.isEmpty || tx.categoryId == 'SYSTEM_ROLLOVER')
            ? null
            : tx.categoryId;

    // 1. Chèn vào bảng transactions
    await txn.insert(
      'transactions',
      {
        'id': tx.id,
        'categoryId': safeCategoryId,
        'amount': tx.amount,
        'type': tx.type,
        'transactionDate': tx.transactionDate.toIso8601String(),
        'status': tx.status,
        'note': tx.note ?? '',
        'createdAt': nowStr,
        'updatedAt': tx.updatedAt?.toIso8601String() ?? nowStr,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 2. Chèn vào bảng transaction_details (nếu có thông tin chi tiết)
    if (detail != null) {
      await txn.insert(
        'transaction_details',
        {
          'id': detail.id.isNotEmpty ? detail.id : '${tx.id}_detail',
          'transactionId': tx.id,
          'note': detail.note,
          'receiptFileId': detail.receiptFileIds.isNotEmpty
              ? detail.receiptFileIds.join(',')
              : null,
          'rawInputText': detail.rawInputText,
          'confidenceScore': detail.confidenceScore,
          'createdAt': nowStr,
          'updatedAt': nowStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final monthYear =
        "${tx.transactionDate.month.toString().padLeft(2, '0')}-${tx.transactionDate.year}";

    // 3. Cập nhật spentAmount trong bảng monthly_budgets (nếu là chi tiêu EXPENSE và có categoryId hợp lệ)
    if (safeCategoryId != null && safeCategoryId.isNotEmpty && tx.type == 'EXPENSE') {
      final existingBudgets = await txn.query(
        'monthly_budgets',
        where: 'categoryId = ? AND monthYear = ?',
        whereArgs: [safeCategoryId, monthYear],
      );

      if (existingBudgets.isNotEmpty) {
        final currentSpent =
            (existingBudgets.first['spentAmount'] as num).toDouble();
        await txn.update(
          'monthly_budgets',
          {'spentAmount': currentSpent + tx.amount, 'updatedAt': nowStr},
          where: 'id = ?',
          whereArgs: [existingBudgets.first['id']],
        );
      } else {
        // Lấy defaultBudget từ category nếu có
        final catRes = await txn.query(
          'categories',
          where: 'id = ?',
          whereArgs: [safeCategoryId],
          limit: 1,
        );
        final defaultBudget = catRes.isNotEmpty
            ? (catRes.first['defaultBudget'] as num?)?.toDouble() ?? 0.0
            : 0.0;

        await txn.insert(
          'monthly_budgets',
          {
            'id': 'mb_${safeCategoryId}_$monthYear',
            'categoryId': safeCategoryId,
            'monthYear': monthYear,
            'budgetedAmount': defaultBudget,
            'rolloverAmount': 0.0,
            'spentAmount': tx.amount,
            'createdAt': nowStr,
            'updatedAt': nowStr,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    // 4. Cập nhật monthly_summaries (totalIncome hoặc totalExpense)
    final existingSummary = await txn.query(
      'monthly_summaries',
      where: 'monthYear = ?',
      whereArgs: [monthYear],
    );

    if (existingSummary.isNotEmpty) {
      double totalIncome =
          (existingSummary.first['totalIncome'] as num).toDouble();
      double totalExpense =
          (existingSummary.first['totalExpense'] as num).toDouble();

      if (tx.type == 'INCOME') {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }

      await txn.update(
        'monthly_summaries',
        {
          'totalIncome': totalIncome,
          'totalExpense': totalExpense,
          'updatedAt': nowStr,
        },
        where: 'id = ?',
        whereArgs: [existingSummary.first['id']],
      );
    } else {
      await txn.insert(
        'monthly_summaries',
        {
          'id': 'ms_$monthYear',
          'monthYear': monthYear,
          'totalIncome': tx.type == 'INCOME' ? tx.amount : 0.0,
          'totalExpense': tx.type == 'EXPENSE' ? tx.amount : 0.0,
          'unallocatedBalance': 0.0,
          'createdAt': nowStr,
          'updatedAt': nowStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 5. Cập nhật currentAmount trong goals nếu danh mục liên kết với mục tiêu
    if (safeCategoryId != null && safeCategoryId.isNotEmpty) {
      final goals = await txn.query(
        'goals',
        where: 'categoryId = ? AND status = ?',
        whereArgs: [safeCategoryId, 'ACTIVE'],
      );
      if (goals.isNotEmpty) {
        final currentGoal = goals.first;
        final currentAmount =
            (currentGoal['currentAmount'] as num?)?.toDouble() ?? 0.0;
        final delta = tx.type == 'INCOME' ? tx.amount : -tx.amount;
        final newAmount =
            (currentAmount + delta) > 0 ? (currentAmount + delta) : 0.0;
        await txn.update(
          'goals',
          {'currentAmount': newAmount, 'updatedAt': nowStr},
          where: 'id = ?',
          whereArgs: [currentGoal['id']],
        );
      }
    }
  }

  /// Xóa nguyên tử giao dịch, dọn dẹp chi tiết biên lai và hoàn tác ngân sách/báo cáo
  Future<void> deleteTransactionAtomic(String txId) async {
    final db = await database;
    await db.transaction((txn) async {
      await _deleteTransactionWithTxn(txn, txId, deletePhysicalFiles: true);
    });
  }

  /// Helper thực thi xóa nguyên tử giao dịch trong một transaction có sẵn
  Future<List<String>> _deleteTransactionWithTxn(
    DatabaseExecutor txn,
    String txId, {
    bool deletePhysicalFiles = true,
  }) async {
    final nowStr = DateTime.now().toIso8601String();

    // 1. Tìm giao dịch cũ
    final txList = await txn.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [txId],
      limit: 1,
    );
    if (txList.isEmpty) return [];

    final tx = txList.first;
    final categoryId = tx['categoryId'] as String?;
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final type = tx['type'] as String? ?? 'EXPENSE';
    final dateStr = tx['transactionDate'] as String?;
    final txDate = dateStr != null
        ? DateTime.tryParse(dateStr) ?? DateTime.now()
        : DateTime.now();
    final monthYear =
        "${txDate.month.toString().padLeft(2, '0')}-${txDate.year}";

    // 2. Trừ ngược lại spentAmount trong monthly_budgets
    if (categoryId != null && categoryId.isNotEmpty && type == 'EXPENSE') {
      final mbList = await txn.query(
        'monthly_budgets',
        where: 'categoryId = ? AND monthYear = ?',
        whereArgs: [categoryId, monthYear],
      );
      if (mbList.isNotEmpty) {
        final currentSpent =
            (mbList.first['spentAmount'] as num).toDouble();
        final newSpent =
            (currentSpent - amount) > 0 ? (currentSpent - amount) : 0.0;
        await txn.update(
          'monthly_budgets',
          {'spentAmount': newSpent, 'updatedAt': nowStr},
          where: 'id = ?',
          whereArgs: [mbList.first['id']],
        );
      }
    }

    // 3. Trừ ngược lại trong monthly_summaries
    final msList = await txn.query(
      'monthly_summaries',
      where: 'monthYear = ?',
      whereArgs: [monthYear],
    );
    if (msList.isNotEmpty) {
      double totalIncome =
          (msList.first['totalIncome'] as num).toDouble();
      double totalExpense =
          (msList.first['totalExpense'] as num).toDouble();
      if (type == 'INCOME') {
        totalIncome =
            (totalIncome - amount) > 0 ? (totalIncome - amount) : 0.0;
      } else {
        totalExpense =
            (totalExpense - amount) > 0 ? (totalExpense - amount) : 0.0;
      }
      await txn.update(
        'monthly_summaries',
        {
          'totalIncome': totalIncome,
          'totalExpense': totalExpense,
          'updatedAt': nowStr,
        },
        where: 'id = ?',
        whereArgs: [msList.first['id']],
      );
    }

    // 4. Hoàn tác goals nếu có
    if (categoryId != null && categoryId.isNotEmpty) {
      final goals = await txn.query(
        'goals',
        where: 'categoryId = ? AND status = ?',
        whereArgs: [categoryId, 'ACTIVE'],
      );
      if (goals.isNotEmpty) {
        final currentGoal = goals.first;
        final currentAmount =
            (currentGoal['currentAmount'] as num?)?.toDouble() ?? 0.0;
        final delta = type == 'INCOME' ? -amount : amount;
        final newAmount =
            (currentAmount + delta) > 0 ? (currentAmount + delta) : 0.0;
        await txn.update(
          'goals',
          {'currentAmount': newAmount, 'updatedAt': nowStr},
          where: 'id = ?',
          whereArgs: [currentGoal['id']],
        );
      }
    }

    // 5. Thu thập danh sách receiptFileId để dọn dẹp file ảnh vật lý (Q6: Lựa chọn A - Xóa vĩnh viễn)
    final details = await txn.query(
      'transaction_details',
      columns: ['receiptFileId'],
      where: 'transactionId = ?',
      whereArgs: [txId],
    );
    final List<String> receiptFilesToDelete = [];
    for (final row in details) {
      final receiptStr = row['receiptFileId'] as String?;
      if (receiptStr != null && receiptStr.isNotEmpty) {
        final parts = receiptStr
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        receiptFilesToDelete.addAll(parts);
      }
    }

    // 6. Xóa chi tiết và giao dịch
    await txn.delete(
      'transaction_details',
      where: 'transactionId = ?',
      whereArgs: [txId],
    );
    await txn.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [txId],
    );

    // 7. Dọn dẹp vĩnh viễn các file ảnh biên lai vật lý trong receipts/ (Q6)
    if (deletePhysicalFiles) {
      for (final fileId in receiptFilesToDelete) {
        _deletePhysicalReceiptFile(fileId);
      }
    }

    return receiptFilesToDelete;
  }

  /// Dọn dẹp file ảnh biên lai vật lý trên ổ cứng thiết bị khi giao dịch bị xóa (Q6: Lựa chọn A)
  Future<void> deletePhysicalReceiptFile(String fileId) async {
    try {
      if (fileId.trim().isEmpty) return;
      final cleanPath = fileId.replaceFirst('file://', '').trim();

      final directFile = File(cleanPath);
      if (await directFile.exists()) {
        await directFile.delete();
        return;
      }

      final docDir = await getApplicationDocumentsDirectory();
      final inReceiptsFile =
          File(p.join(docDir.path, 'receipts', p.basename(cleanPath)));
      if (await inReceiptsFile.exists()) {
        await inReceiptsFile.delete();
      }
    } catch (_) {
      // Bỏ qua lỗi xóa file vật lý để không làm ảnh hưởng tính toàn vẹn của CSDL
    }
  }

  Future<void> _deletePhysicalReceiptFile(String fileId) =>
      deletePhysicalReceiptFile(fileId);

  /// Cập nhật nguyên tử giao dịch
  Future<void> updateTransactionAtomic(
    TransactionModel newTx, {
    TransactionDetailModel? detail,
  }) async {
    final db = await database;
    List<String> oldReceiptFiles = [];
    await db.transaction((txn) async {
      // Hoàn tác giao dịch cũ trước (giữ ảnh cũ)
      oldReceiptFiles = await _deleteTransactionWithTxn(
        txn,
        newTx.id,
        deletePhysicalFiles: false,
      );
      // Ghi lại giao dịch mới
      await _insertTransactionWithTxn(txn, newTx, detail: detail);
    });

    // Sau khi insert xong giao dịch mới, so sánh danh sách ảnh cũ và mới:
    // chỉ xóa những ảnh không còn xuất hiện trong giao dịch mới
    final newReceiptFiles = detail?.receiptFileIds ?? [];
    for (final oldFile in oldReceiptFiles) {
      if (!newReceiptFiles.contains(oldFile)) {
        await _deletePhysicalReceiptFile(oldFile);
      }
    }
  }

  /// Lấy chi tiết mở rộng của giao dịch (ảnh biên lai, rawInput, confidence)
  Future<TransactionDetailModel?> getTransactionDetail(
    String transactionId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transaction_details',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TransactionDetailModel.fromMap(maps.first);
  }
}
