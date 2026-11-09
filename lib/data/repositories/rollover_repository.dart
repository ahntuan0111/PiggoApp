import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/monthly_budget_model.dart';
import 'package:appintern/data/models/monthly_summary_model.dart';
import 'package:get/get.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/core/utils/offline_helper.dart';
import 'package:sqflite/sqflite.dart';

enum RolloverState {
  newAccount,
  noPending,
  normalRollover,
  multiMonthGap,
}

class RolloverStateResult {
  final RolloverState state;
  final String? lastActiveMonthYear;

  RolloverStateResult(this.state, {this.lastActiveMonthYear});
}

class RolloverData {
  final MonthlySummaryModel? summary;
  final List<MonthlyBudgetModel> budgets;
  final List<CategoryModel> categories;
  final double totalWalletBalance;

  RolloverData({
    required this.summary,
    required this.budgets,
    required this.categories,
    required this.totalWalletBalance,
  });
}

class RolloverRepository {
  final LocalDatabaseService _localDb;

  RolloverRepository()
      : _localDb = Get.find<LocalDatabaseService>();

  /// Kiểm tra trạng thái Rollover dựa trên dữ liệu SQLite cục bộ
  /// Bảo toàn 100% logic xác định: newAccount, noPending, normalRollover, multiMonthGap
  Future<RolloverStateResult> checkRolloverState([String? userId]) async {
    final uid = userId ?? _localDb.currentUserId;
    final db = await _localDb.database;
    final now = DateTime.now();
    final currentMonthStr =
        "${now.month.toString().padLeft(2, '0')}-${now.year}";

    // 0. Xác định danh mục của người dùng hiện tại
    final types = await db.query(
      'category_types',
      where: 'userId = ?',
      whereArgs: [uid],
    );
    if (types.isEmpty) {
      return RolloverStateResult(RolloverState.newAccount);
    }

    final categories = await db.query(
      'categories',
      where: 'userId = ?',
      whereArgs: [uid],
    );
    if (categories.isEmpty) {
      return RolloverStateResult(RolloverState.newAccount);
    }

    // 1. Kiểm tra tháng hiện tại đã khởi tạo chưa
    final currentBudgets = await db.query(
      'monthly_budgets',
      where: 'monthYear = ? AND userId = ?',
      whereArgs: [currentMonthStr, uid],
      limit: 1,
    );

    if (currentBudgets.isNotEmpty) {
      return RolloverStateResult(RolloverState.noPending);
    }

    // 2. Tìm tháng liền trước gần nhất có dữ liệu
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final prevMonthStr =
        "${prevMonth.month.toString().padLeft(2, '0')}-${prevMonth.year}";

    final prevBudgets = await db.query(
      'monthly_budgets',
      where: 'monthYear = ? AND userId = ?',
      whereArgs: [prevMonthStr, uid],
      limit: 1,
    );

    if (prevBudgets.isNotEmpty) {
      return RolloverStateResult(
        RolloverState.normalRollover,
        lastActiveMonthYear: prevMonthStr,
      );
    }

    // 3. Nếu không có tháng trước, kiểm tra xem có BẤT KỲ budget nào trong lịch sử không
    final anyHistory = await db.query(
      'monthly_budgets',
      where: 'monthYear != ? AND userId = ?',
      whereArgs: [currentMonthStr, uid],
      orderBy: 'createdAt DESC',
      limit: 1,
    );

    if (anyHistory.isNotEmpty) {
      final lastMonth = anyHistory.first['monthYear'] as String?;
      return RolloverStateResult(
        RolloverState.multiMonthGap,
        lastActiveMonthYear: lastMonth,
      );
    }

    return RolloverStateResult(RolloverState.newAccount);
  }

  /// Lấy dữ liệu Rollover cho tháng được chỉ định từ SQLite cục bộ
  Future<RolloverData> getRolloverData(String userId, String monthYear) async {
    final uid = userId.isNotEmpty ? userId : _localDb.currentUserId;
    final db = await _localDb.database;

    // 1. Fetch Categories
    final catRows = await db.query(
      'categories',
      where: 'userId = ?',
      whereArgs: [uid],
    );
    final categories = catRows.map((r) => CategoryModel.fromMap(r)).toList();

    // 2. Fetch Summary của monthYear
    final summaryRows = await db.query(
      'monthly_summaries',
      where: 'monthYear = ? AND userId = ?',
      whereArgs: [monthYear, uid],
      limit: 1,
    );

    MonthlySummaryModel? summary;
    if (summaryRows.isNotEmpty) {
      summary = MonthlySummaryModel.fromMap(summaryRows.first);
    }

    // 3. Fetch Budgets của monthYear
    final budgetRows = await db.query(
      'monthly_budgets',
      where: 'monthYear = ? AND userId = ?',
      whereArgs: [monthYear, uid],
    );

    final budgets =
        budgetRows.map((b) => MonthlyBudgetModel.fromMap(b)).toList();

    double totalWalletBalance = 0.0;

    return RolloverData(
      summary: summary,
      budgets: budgets,
      categories: categories,
      totalWalletBalance: totalWalletBalance,
    );
  }

  /// Khởi tạo ngân sách sạch cho tài khoản mới hoặc khi Hard Reset sau Multi-Month Gap
  Future<void> executeHardReset(
    String userId, {
    Set<String> goalCategoryIds = const {},
  }) async {
    final uid = userId.isNotEmpty ? userId : _localDb.currentUserId;
    final db = await _localDb.database;
    final now = DateTime.now();
    final currentMonthStr =
        "${now.month.toString().padLeft(2, '0')}-${now.year}";

    final categories = await db.query(
      'categories',
      where: 'userId = ?',
      whereArgs: [uid],
    );
    if (categories.isEmpty) return;

    await db.transaction((txn) async {
      for (var catDoc in categories) {
        final catId = catDoc['id'] as String;
        final bool isGoal = goalCategoryIds.contains(catId);

        await txn.insert(
          'monthly_budgets',
          {
            'id': OfflineHelper.generateTempId('mb_${catId}_$currentMonthStr'),
            'userId': uid,
            'categoryId': catId,
            'monthYear': currentMonthStr,
            'budgetedAmount': isGoal ? 0.0 : 0.0,
            'rolloverAmount': 0.0,
            'spentAmount': 0.0,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Ghi snapshot chốt sổ chu kỳ vào bảng budgets_history
      await txn.insert(
        'budgets_history',
        {
          'id': OfflineHelper.generateTempId('bh_$currentMonthStr'),
          'userId': uid,
          'monthYear': currentMonthStr,
          'totalInflow': 0.0,
          'totalOutflow': 0.0,
          'rolloverMethod': 'HARD_RESET',
          'createdAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Thực hiện kết chuyển Rollover từ chu kỳ cũ sang chu kỳ mới
  Future<void> executeRollover(
    String userId,
    Map<String, double> updatedBudgets,
    Map<String, double> rolloverAmounts, {
    Set<String> goalCategoryIds = const {},
  }) async {
    final uid = userId.isNotEmpty ? userId : _localDb.currentUserId;
    final db = await _localDb.database;
    final now = DateTime.now();
    final currentMonthStr =
        "${now.month.toString().padLeft(2, '0')}-${now.year}";

    final categories = await db.query(
      'categories',
      where: 'userId = ?',
      whereArgs: [uid],
    );
    if (categories.isEmpty) return;

    double totalInflow = 0.0;
    double totalOutflow = 0.0;

    await db.transaction((txn) async {
      for (var catDoc in categories) {
        final catId = catDoc['id'] as String;
        final bool isGoal = goalCategoryIds.contains(catId);

        final defaultBudget = isGoal
            ? 0.0
            : (updatedBudgets[catId] ??
                (catDoc['defaultBudget'] as num? ?? 0).toDouble());

        final rolloverAmt = rolloverAmounts[catId] ?? 0.0;

        totalInflow += defaultBudget;
        totalOutflow += rolloverAmt;

        await txn.insert(
          'monthly_budgets',
          {
            'id': OfflineHelper.generateTempId('mb_${catId}_$currentMonthStr'),
            'userId': uid,
            'categoryId': catId,
            'monthYear': currentMonthStr,
            'budgetedAmount': defaultBudget,
            'rolloverAmount': rolloverAmt,
            'spentAmount': 0.0,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Ghi snapshot chốt sổ chu kỳ vào bảng budgets_history theo chuẩn spec Q5
      await txn.insert(
        'budgets_history',
        {
          'id': OfflineHelper.generateTempId('bh_$currentMonthStr'),
          'userId': uid,
          'monthYear': currentMonthStr,
          'totalInflow': totalInflow,
          'totalOutflow': totalOutflow,
          'rolloverMethod': 'ROLLOVER_ALL',
          'createdAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Xóa toàn bộ dữ liệu trong một tháng chỉ định của user (Giao dịch, ngân sách tháng, tổng kết tháng)
  Future<void> clearMonthData(String monthYear, [String? userId]) async {
    final uid = userId ?? _localDb.currentUserId;
    final parts = monthYear.split('-');
    if (parts.length != 2) {
      throw Exception("Định dạng tháng năm không hợp lệ");
    }
    final month = int.parse(parts[0]);
    final year = int.parse(parts[1]);

    final start = DateTime(year, month, 1);
    final end = DateTime(
      year,
      month + 1,
      1,
    ).subtract(const Duration(milliseconds: 1));

    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final db = await _localDb.database;
    final Set<String> receiptFilesToDelete = {};

    await db.transaction((txn) async {
      // 0. Thu thập danh sách receiptFileId để dọn dẹp file ảnh biên lai vật lý
      final details = await txn.rawQuery(
        '''
        SELECT td.receiptFileId
        FROM transaction_details td
        JOIN transactions t ON td.transactionId = t.id
        WHERE t.userId = ? AND t.transactionDate BETWEEN ? AND ?
        ''',
        [uid, startIso, endIso],
      );

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

      // 1. Xóa các transactions trong tháng của user
      await txn.delete(
        'transactions',
        where: 'userId = ? AND transactionDate BETWEEN ? AND ?',
        whereArgs: [uid, startIso, endIso],
      );

      // 2. Xóa ngân sách tháng của tháng đó của user
      await txn.delete(
        'monthly_budgets',
        where: 'userId = ? AND monthYear = ?',
        whereArgs: [uid, monthYear],
      );

      // 3. Xóa báo cáo tháng trong tháng đó của user
      await txn.delete(
        'monthly_summaries',
        where: 'userId = ? AND monthYear = ?',
        whereArgs: [uid, monthYear],
      );
    });

    // 4. Dọn dẹp vĩnh viễn các file ảnh biên lai vật lý trên ổ cứng thiết bị
    for (final fileId in receiptFilesToDelete) {
      await _localDb.deletePhysicalReceiptFile(fileId);
    }
  }
}
