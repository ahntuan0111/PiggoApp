import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';

mixin LocalDbTransactionMixin on LocalDatabaseBase {
  Future<void> saveTransactions(
    List<TransactionModel> txs, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    Batch batch = db.batch();
    for (var tx in txs) {
      final String? safeCategoryId =
          (tx.categoryId.isEmpty || tx.categoryId == 'SYSTEM_ROLLOVER')
              ? null
              : tx.categoryId;
      batch.insert('transactions', {
        'id': tx.id,
        'userId': tx.userId ?? effectiveUserId,
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

  Future<bool> hasAnyTransactions({String? userId}) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM transactions WHERE userId = ?',
        [effectiveUserId],
      ),
    );
    return (count ?? 0) > 0;
  }

  Future<List<TransactionModel>> getAllTransactions({String? userId}) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ?',
      whereArgs: [effectiveUserId],
      orderBy: 'transactionDate DESC',
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByMonth(
    String monthYearStr, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    // monthYearStr có định dạng MM-YYYY
    final parts = monthYearStr.split('-');
    if (parts.length != 2) return [];

    final year = parts[1];
    final month = parts[0].padLeft(2, '0');
    final startPrefix = '$year-$month-'; // Ví dụ: 2026-07-

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ? AND transactionDate LIKE ?',
      whereArgs: [effectiveUserId, '$startPrefix%'],
      orderBy: 'transactionDate DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel(
        id: maps[i]['id'] as String,
        userId: maps[i]['userId'] as String?,
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
    DateTime end, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ? AND transactionDate >= ? AND transactionDate <= ?',
      whereArgs: [
        effectiveUserId,
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'transactionDate DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel(
        id: maps[i]['id'] as String,
        userId: maps[i]['userId'] as String?,
        categoryId: (maps[i]['categoryId'] as String?) ?? '',
        amount: (maps[i]['amount'] as num).toDouble(),
        type: maps[i]['type'] as String,
        transactionDate: DateTime.parse(maps[i]['transactionDate'] as String),
        status: maps[i]['status'] as String,
        note: maps[i]['note'] as String?,
      );
    });
  }

  Future<TransactionModel?> getTransactionById(
    String transactionId, {
    String? userId,
  }) async {
    final db = await database;
    final whereClause = userId != null ? 'id = ? AND userId = ?' : 'id = ?';
    final whereArgs = userId != null ? [transactionId, userId] : [transactionId];
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TransactionModel(
      id: maps[0]['id'] as String,
      userId: maps[0]['userId'] as String?,
      categoryId: (maps[0]['categoryId'] as String?) ?? '',
      amount: (maps[0]['amount'] as num).toDouble(),
      type: maps[0]['type'] as String,
      transactionDate: DateTime.parse(maps[0]['transactionDate'] as String),
      status: maps[0]['status'] as String,
      note: maps[0]['note'] as String?,
    );
  }

  /// Truy vấn lịch sử giao dịch kết hợp JOIN categories và transaction_details
  /// Hỗ trợ phân trang chuẩn SQL (LIMIT / OFFSET hoặc Keyset pagination với cursorAfter),
  /// sắp xếp và lọc theo danh mục, loại giao dịch, khoảng thời gian và từ khóa.
  Future<List<Map<String, dynamic>>> getTransactionsWithDetailsAndCategory({
    String? userId,
    DateTime? start,
    DateTime? end,
    String? categoryId,
    String? type,
    String? searchQuery,
    int limit = 20,
    int offset = 0,
    String? cursorAfter,
    bool ascending = false,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;

    final whereConditions = <String>['t.userId = ?'];
    final whereArgs = <dynamic>[effectiveUserId];

    if (start != null) {
      whereConditions.add('t.transactionDate >= ?');
      whereArgs.add(start.toIso8601String());
    }

    if (end != null) {
      whereConditions.add('t.transactionDate <= ?');
      whereArgs.add(end.toIso8601String());
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      whereConditions.add('t.categoryId = ?');
      whereArgs.add(categoryId);
    }

    if (type != null && type.isNotEmpty) {
      whereConditions.add('t.type = ?');
      whereArgs.add(type);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereConditions.add('(t.note LIKE ? OR td.note LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    // Keyset pagination với cursorAfter (id của transaction cuối cùng từ trang trước)
    if (cursorAfter != null && cursorAfter.isNotEmpty) {
      final cursorRow = await db.query(
        'transactions',
        columns: ['transactionDate'],
        where: 'id = ?',
        whereArgs: [cursorAfter],
        limit: 1,
      );
      if (cursorRow.isNotEmpty) {
        final cursorDate = cursorRow.first['transactionDate'] as String;
        if (ascending) {
          whereConditions.add(
            '(t.transactionDate > ? OR (t.transactionDate = ? AND t.id > ?))',
          );
        } else {
          whereConditions.add(
            '(t.transactionDate < ? OR (t.transactionDate = ? AND t.id < ?))',
          );
        }
        whereArgs.add(cursorDate);
        whereArgs.add(cursorDate);
        whereArgs.add(cursorAfter);
      }
    }

    final whereClause = whereConditions.join(' AND ');
    final orderDirection = ascending ? 'ASC' : 'DESC';
    final orderByClause =
        't.transactionDate $orderDirection, t.id $orderDirection';

    final sql = StringBuffer();
    sql.write('''
      SELECT 
        t.id AS tx_id,
        t.userId AS tx_userId,
        t.categoryId AS tx_categoryId,
        t.amount AS tx_amount,
        t.type AS tx_type,
        t.transactionDate AS tx_transactionDate,
        t.status AS tx_status,
        t.note AS tx_note,
        t.createdAt AS tx_createdAt,
        t.updatedAt AS tx_updatedAt,
        c.id AS cat_id,
        c.name AS cat_name,
        c.color AS cat_color,
        c.iconName AS cat_iconName,
        td.id AS detail_id,
        td.transactionId AS detail_transactionId,
        td.note AS detail_note,
        td.receiptFileId AS detail_receiptFileId,
        td.rawInputText AS detail_rawInputText,
        td.confidenceScore AS detail_confidenceScore
      FROM transactions t
      LEFT JOIN categories c ON t.categoryId = c.id
      LEFT JOIN transaction_details td ON t.id = td.transactionId
      WHERE $whereClause
      ORDER BY $orderByClause
      LIMIT ?
    ''');
    whereArgs.add(limit);

    if (offset > 0 && (cursorAfter == null || cursorAfter.isEmpty)) {
      sql.write(' OFFSET ?');
      whereArgs.add(offset);
    }

    final rows = await db.rawQuery(sql.toString(), whereArgs);

    return rows.map((row) {
      final tx = TransactionModel(
        id: row['tx_id'] as String,
        userId: row['tx_userId'] as String?,
        categoryId: (row['tx_categoryId'] as String?) ?? '',
        amount: (row['tx_amount'] as num).toDouble(),
        type: row['tx_type'] as String? ?? 'EXPENSE',
        transactionDate:
            DateTime.tryParse(row['tx_transactionDate'] as String? ?? '')
                    ?.toLocal() ??
                DateTime.now(),
        status: row['tx_status'] as String? ?? 'COMPLETED',
        note: row['tx_note'] as String?,
        updatedAt: row['tx_updatedAt'] != null
            ? DateTime.tryParse(row['tx_updatedAt'] as String)?.toLocal()
            : null,
      );

      TransactionDetailModel? detail;
      if (row['detail_id'] != null ||
          row['detail_note'] != null ||
          row['detail_receiptFileId'] != null ||
          row['detail_rawInputText'] != null) {
        List<String> parsedFileIds = [];
        final receiptStr = row['detail_receiptFileId'] as String?;
        if (receiptStr != null && receiptStr.isNotEmpty) {
          parsedFileIds = receiptStr
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        detail = TransactionDetailModel(
          id: (row['detail_id'] as String?) ?? '${tx.id}_detail',
          transactionId: (row['detail_transactionId'] as String?) ?? tx.id,
          note: (row['detail_note'] as String?) ?? '',
          receiptFileIds: parsedFileIds,
          rawInputText: (row['detail_rawInputText'] as String?) ?? '',
          confidenceScore:
              (row['detail_confidenceScore'] as num?)?.toDouble() ?? 0.0,
        );
      }

      return {
        'transaction': tx,
        'detail': detail,
        'categoryName': (row['cat_name'] as String?) ?? 'Giao dịch',
        'categoryColor': (row['cat_color'] as String?) ?? '#EBC14F',
        'categoryIcon': (row['cat_iconName'] as String?) ?? 'icon_wallet.png',
      };
    }).toList();
  }

  // =========================================================================
  // ATOMIC SQLITE TRANSACTIONS (GIAI ĐOẠN 1 MIGRATION)
  // =========================================================================

  /// Ghi nguyên tử giao dịch, chi tiết biên lai, cập nhật ngân sách và báo cáo tháng
  Future<void> insertTransactionAtomic(
    TransactionModel tx, {
    TransactionDetailModel? detail,
    String? userId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await _insertTransactionWithTxn(
        txn,
        tx,
        detail: detail,
        userId: userId,
      );
    });
  }

  /// Helper thực thi ghi nguyên tử giao dịch trong một transaction có sẵn
  Future<void> _insertTransactionWithTxn(
    DatabaseExecutor txn,
    TransactionModel tx, {
    TransactionDetailModel? detail,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? tx.userId ?? currentUserId;
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
        'userId': effectiveUserId,
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
        where: 'categoryId = ? AND monthYear = ? AND userId = ?',
        whereArgs: [safeCategoryId, monthYear, effectiveUserId],
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
          where: 'id = ? AND userId = ?',
          whereArgs: [safeCategoryId, effectiveUserId],
          limit: 1,
        );
        final defaultBudget = catRes.isNotEmpty
            ? (catRes.first['defaultBudget'] as num?)?.toDouble() ?? 0.0
            : 0.0;

        await txn.insert(
          'monthly_budgets',
          {
            'id': 'mb_${safeCategoryId}_$monthYear',
            'userId': effectiveUserId,
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
      where: 'monthYear = ? AND userId = ?',
      whereArgs: [monthYear, effectiveUserId],
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
          'id': 'ms_${effectiveUserId}_$monthYear',
          'userId': effectiveUserId,
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
        where: 'categoryId = ? AND status = ? AND userId = ?',
        whereArgs: [safeCategoryId, 'ACTIVE', effectiveUserId],
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
    final txUserId = tx['userId'] as String? ?? currentUserId;
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
        where: 'categoryId = ? AND monthYear = ? AND userId = ?',
        whereArgs: [categoryId, monthYear, txUserId],
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
      where: 'monthYear = ? AND userId = ?',
      whereArgs: [monthYear, txUserId],
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
        where: 'categoryId = ? AND status = ? AND userId = ?',
        whereArgs: [categoryId, 'ACTIVE', txUserId],
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

    // 5. Thu thập danh sách receiptFileId để dọn dẹp file ảnh biên lai vật lý
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

    // 7. Dọn dẹp vĩnh viễn các file ảnh biên lai vật lý trong receipts/
    if (deletePhysicalFiles) {
      for (final fileId in receiptFilesToDelete) {
        _deletePhysicalReceiptFile(fileId);
      }
    }

    return receiptFilesToDelete;
  }

  /// Dọn dẹp file ảnh biên lai vật lý trên ổ cứng thiết bị khi giao dịch bị xóa
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
    String? userId,
  }) async {
    final effectiveUserId = userId ?? newTx.userId ?? currentUserId;
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
      await _insertTransactionWithTxn(
        txn,
        newTx,
        detail: detail,
        userId: effectiveUserId,
      );
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
