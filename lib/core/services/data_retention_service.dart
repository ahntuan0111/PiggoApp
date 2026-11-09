import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/utils/logger.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';

/// Thống kê kết quả của tiến trình dọn dẹp và lưu trữ dữ liệu cũ
class RetentionStats {
  final int prunedTransactions;
  final int prunedReceipts;
  final int freedBytes;
  final List<String> archivedMonths;

  RetentionStats({
    this.prunedTransactions = 0,
    this.prunedReceipts = 0,
    this.freedBytes = 0,
    this.archivedMonths = const [],
  });

  String get freedSizeFormatted {
    if (freedBytes <= 0) return '0 B';
    if (freedBytes < 1024) return '$freedBytes B';
    if (freedBytes < 1024 * 1024) {
      return '${(freedBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(freedBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  String toString() {
    return 'RetentionStats(prunedTransactions: $prunedTransactions, prunedReceipts: $prunedReceipts, freed: $freedSizeFormatted, months: $archivedMonths)';
  }
}

/// Dịch vụ quản lý vòng đời và dọn dẹp dữ liệu (Data Retention & Pruning Layer).
/// 
/// Nguyên tắc hoạt động:
/// 1. Chỉ giữ lại đầy đủ giao dịch chi tiết và ảnh biên lai của 2 tháng gần nhất (Tháng hiện tại và Tháng trước).
/// 2. Các giao dịch cũ hơn 2 tháng sẽ được đóng băng (Archive) vào:
///    - `monthly_summaries`: Tổng thu và tổng chi của tháng đó.
///    - `monthly_category_summaries`: Chi tiết chi tiêu theo từng danh mục của tháng đó (phục vụ biểu đồ thống kê Donut & Trend).
/// 3. Sau khi đảm bảo toàn vẹn dữ liệu thống kê, các giao dịch và ảnh hóa đơn vật lý tương ứng sẽ được dọn dẹp sạch sẽ.
class DataRetentionService extends GetxService {
  final LocalDatabaseService? _localDbOverride;
  final StorageService? _storageOverride;

  LocalDatabaseService get _localDb =>
      _localDbOverride ?? Get.find<LocalDatabaseService>();
  StorageService get _storage =>
      _storageOverride ?? Get.find<StorageService>();

  static const String keyLastRetentionRun = 'last_data_retention_timestamp';

  DataRetentionService({
    LocalDatabaseService? localDb,
    StorageService? storage,
  })  : _localDbOverride = localDb,
        _storageOverride = storage;

  /// Tính toán thời điểm cắt (Cutoff Date) cho chính sách lưu trữ.
  /// Mặc định retentionMonths = 2: Giữ tháng hiện tại (T) và tháng trước (T-1).
  /// Cutoff Date là ngày 1 của tháng (T-1).
  DateTime calculateCutoffDate([int retentionMonths = 2]) {
    final now = DateTime.now();
    // Ví dụ: now là 10-2026, retentionMonths = 2:
    // now.month - (2 - 1) = month 9.
    // Cutoff là ngày 01-09-2026 00:00:00. Mọi tx trước ngày này sẽ được prune.
    return DateTime(now.year, now.month - (retentionMonths - 1), 1);
  }

  /// Xem trước số lượng bản ghi và dung lượng có thể dọn dẹp (Preview)
  Future<RetentionStats> getRetentionPreview({
    String? userId,
    int retentionMonths = 2,
  }) async {
    final effectiveUserId = userId ?? _localDb.currentUserId;
    final db = await _localDb.database;
    final cutoffDate = calculateCutoffDate(retentionMonths);
    final cutoffIso = cutoffDate.toIso8601String();

    // 1. Đếm số lượng transactions cũ
    final txCountResult = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM transactions WHERE userId = ? AND transactionDate < ?',
        [effectiveUserId, cutoffIso],
      ),
    );
    final txCount = txCountResult ?? 0;

    if (txCount == 0) {
      return RetentionStats(
        prunedTransactions: 0,
        prunedReceipts: 0,
        freedBytes: 0,
        archivedMonths: const [],
      );
    }

    // 2. Tìm các tháng bị ảnh hưởng
    final monthsQuery = await db.rawQuery(
      '''
      SELECT DISTINCT substr(transactionDate, 6, 2) || '-' || substr(transactionDate, 1, 4) AS mYear
      FROM transactions
      WHERE userId = ? AND transactionDate < ?
      ORDER BY transactionDate ASC
      ''',
      [effectiveUserId, cutoffIso],
    );
    final List<String> months = monthsQuery
        .map((r) => r['mYear'] as String? ?? '')
        .where((m) => m.isNotEmpty)
        .toList();

    // 3. Đếm số file ảnh và tính dung lượng ước tính
    final details = await db.rawQuery(
      '''
      SELECT td.receiptFileId
      FROM transaction_details td
      JOIN transactions t ON td.transactionId = t.id
      WHERE t.userId = ? AND t.transactionDate < ?
      ''',
      [effectiveUserId, cutoffIso],
    );

    int receiptCount = 0;
    int estimatedBytes = 0;
    final docDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(docDir.path, 'receipts'));

    for (final row in details) {
      final receiptStr = row['receiptFileId'] as String?;
      if (receiptStr != null && receiptStr.isNotEmpty) {
        final parts = receiptStr
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        for (final fileId in parts) {
          receiptCount++;
          final filePath = p.isAbsolute(fileId)
              ? fileId
              : p.join(receiptsDir.path, p.basename(fileId));
          final file = File(filePath);
          if (await file.exists()) {
            estimatedBytes += await file.length();
          }
        }
      }
    }

    return RetentionStats(
      prunedTransactions: txCount,
      prunedReceipts: receiptCount,
      freedBytes: estimatedBytes,
      archivedMonths: months,
    );
  }

  /// Thực thi toàn bộ tiến trình dọn dẹp dữ liệu cũ (Giữ lại 2 tháng gần nhất)
  Future<RetentionStats> pruneOldData({
    String? userId,
    int retentionMonths = 2,
  }) async {
    final effectiveUserId = userId ?? _localDb.currentUserId;
    final db = await _localDb.database;
    final cutoffDate = calculateCutoffDate(retentionMonths);
    final cutoffIso = cutoffDate.toIso8601String();

    AppLogger.info(
      'DATA_RETENTION',
      'Bắt đầu kiểm tra và dọn dẹp dữ liệu cũ trước ngày $cutoffIso cho user $effectiveUserId',
    );

    // 1. Lấy toàn bộ các giao dịch cũ thuộc diện dọn dẹp
    final oldTransactions = await db.rawQuery(
      '''
      SELECT t.id, t.categoryId, t.amount, t.type, t.transactionDate,
             c.name AS catName, c.color AS catColor, c.iconName AS catIcon
      FROM transactions t
      LEFT JOIN categories c ON t.categoryId = c.id
      WHERE t.userId = ? AND t.transactionDate < ?
      ORDER BY t.transactionDate ASC
      ''',
      [effectiveUserId, cutoffIso],
    );

    if (oldTransactions.isEmpty) {
      AppLogger.info(
        'DATA_RETENTION',
        'Không có giao dịch nào cũ hơn 2 tháng cần dọn dẹp.',
      );
      _storage.write(keyLastRetentionRun, DateTime.now().millisecondsSinceEpoch);
      return RetentionStats(
        prunedTransactions: 0,
        prunedReceipts: 0,
        freedBytes: 0,
        archivedMonths: const [],
      );
    }

    // 2. Gom nhóm theo tháng (monthYear có định dạng MM-YYYY)
    final Map<String, List<Map<String, dynamic>>> txsByMonth = {};
    for (final tx in oldTransactions) {
      final dateStr = tx['transactionDate'] as String;
      final parsed = DateTime.tryParse(dateStr) ?? cutoffDate;
      final monthStr =
          "${parsed.month.toString().padLeft(2, '0')}-${parsed.year}";
      txsByMonth.putIfAbsent(monthStr, () => []).add(tx);
    }

    final List<String> archivedMonths = txsByMonth.keys.toList();

    // 3. ĐÓNG BĂNG VÀ TỔNG HỢP DỮ LIỆU VÀO KHO LƯU TRỮ THỐNG KÊ (ARCHIVING)
    await db.transaction((txn) async {
      for (final entry in txsByMonth.entries) {
        final monthYear = entry.key;
        final txList = entry.value;

        // A. Tổng hợp tổng thu nhập và tổng chi tiêu tháng
        double monthIncome = 0.0;
        double monthExpense = 0.0;
        final Map<String, Map<String, dynamic>> catGroup = {};

        for (final tx in txList) {
          final amount = (tx['amount'] as num).toDouble();
          final type = tx['type'] as String? ?? 'EXPENSE';
          final catId = (tx['categoryId'] as String?) ?? 'uncategorized';

          if (type == 'INCOME') {
            monthIncome += amount;
          } else {
            monthExpense += amount;
          }

          if (!catGroup.containsKey(catId)) {
            catGroup[catId] = {
              'categoryId': catId,
              'categoryName': (tx['catName'] as String?) ?? 'Khác',
              'categoryColor': (tx['catColor'] as String?) ?? '#9E9E9E',
              'categoryIcon': (tx['catIcon'] as String?) ?? 'icon_wallet.png',
              'totalExpense': 0.0,
              'totalIncome': 0.0,
              'transactionCount': 0,
            };
          }

          if (type == 'INCOME') {
            catGroup[catId]!['totalIncome'] =
                (catGroup[catId]!['totalIncome'] as double) + amount;
          } else {
            catGroup[catId]!['totalExpense'] =
                (catGroup[catId]!['totalExpense'] as double) + amount;
          }
          catGroup[catId]!['transactionCount'] =
              (catGroup[catId]!['transactionCount'] as int) + 1;
        }

        // B. Bảo toàn/Đảm bảo monthly_summaries có số liệu chính xác
        final existingSummary = await txn.query(
          'monthly_summaries',
          where: 'monthYear = ? AND userId = ?',
          whereArgs: [monthYear, effectiveUserId],
        );

        final nowIso = DateTime.now().toIso8601String();
        if (existingSummary.isEmpty) {
          await txn.insert(
            'monthly_summaries',
            {
              'id': 'ms_${effectiveUserId}_$monthYear',
              'userId': effectiveUserId,
              'monthYear': monthYear,
              'totalIncome': monthIncome,
              'totalExpense': monthExpense,
              'unallocatedBalance': 0.0,
              'createdAt': nowIso,
              'updatedAt': nowIso,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          // Nếu đã có nhưng có thể bị lệch, cập nhật lại cho chuẩn xác
          await txn.update(
            'monthly_summaries',
            {
              'totalIncome': monthIncome,
              'totalExpense': monthExpense,
              'updatedAt': nowIso,
            },
            where: 'id = ?',
            whereArgs: [existingSummary.first['id']],
          );
        }

        // C. Lưu dữ liệu phân loại chi tiết vào monthly_category_summaries
        for (final catItem in catGroup.values) {
          final cId = catItem['categoryId'] as String;
          final mcsId = 'mcs_${effectiveUserId}_${cId}_$monthYear';

          await txn.insert(
            'monthly_category_summaries',
            {
              'id': mcsId,
              'userId': effectiveUserId,
              'monthYear': monthYear,
              'categoryId': cId,
              'categoryName': catItem['categoryName'],
              'categoryColor': catItem['categoryColor'],
              'categoryIcon': catItem['categoryIcon'],
              'totalExpense': catItem['totalExpense'],
              'totalIncome': catItem['totalIncome'],
              'transactionCount': catItem['transactionCount'],
              'createdAt': nowIso,
              'updatedAt': nowIso,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    AppLogger.info(
      'DATA_RETENTION',
      'Đã hoàn tất tổng hợp số liệu cho ${archivedMonths.length} tháng: $archivedMonths',
    );

    // 4. Thu thập danh sách receiptFileId cần xóa vật lý
    final detailsToDelete = await db.rawQuery(
      '''
      SELECT td.receiptFileId
      FROM transaction_details td
      JOIN transactions t ON td.transactionId = t.id
      WHERE t.userId = ? AND t.transactionDate < ?
      ''',
      [effectiveUserId, cutoffIso],
    );

    final Set<String> physicalReceiptFiles = {};
    for (final row in detailsToDelete) {
      final receiptStr = row['receiptFileId'] as String?;
      if (receiptStr != null && receiptStr.isNotEmpty) {
        final parts = receiptStr
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        physicalReceiptFiles.addAll(parts);
      }
    }

    // 5. THỰC THI XÓA TRANSACTIONS VÀ DETAILS TRONG CSDL (ATOMIC)
    int deletedTransactionsCount = 0;
    await db.transaction((txn) async {
      await txn.rawDelete(
        '''
        DELETE FROM transaction_details
        WHERE transactionId IN (
          SELECT id FROM transactions
          WHERE userId = ? AND transactionDate < ?
        )
        ''',
        [effectiveUserId, cutoffIso],
      );

      deletedTransactionsCount = await txn.delete(
        'transactions',
        where: 'userId = ? AND transactionDate < ?',
        whereArgs: [effectiveUserId, cutoffIso],
      );
    });

    // 6. XÓA FILE ẢNH VẬT LÝ TRONG THƯ MỤC RECEIPTS/
    int freedBytes = 0;
    int deletedReceiptsCount = 0;
    final docDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(docDir.path, 'receipts'));

    for (final fileId in physicalReceiptFiles) {
      try {
        final filePath = p.isAbsolute(fileId)
            ? fileId
            : p.join(receiptsDir.path, p.basename(fileId));
        final file = File(filePath);
        if (await file.exists()) {
          freedBytes += await file.length();
          await file.delete();
          deletedReceiptsCount++;
        }
      } catch (e) {
        AppLogger.error(
          'DATA_RETENTION',
          'Lỗi khi xóa file ảnh vật lý $fileId: $e',
        );
      }
    }

    // 7. THU HỒI DUNG LƯỢNG BỘ NHỚ SQLITE (VACUUM & CHECKPOINT)
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      await db.execute('VACUUM;');
    } catch (e) {
      AppLogger.info(
        'DATA_RETENTION',
        'Không thể chạy VACUUM giải phóng ổ cứng: $e',
      );
    }

    _storage.write(keyLastRetentionRun, DateTime.now().millisecondsSinceEpoch);

    final stats = RetentionStats(
      prunedTransactions: deletedTransactionsCount,
      prunedReceipts: deletedReceiptsCount,
      freedBytes: freedBytes,
      archivedMonths: archivedMonths,
    );

    AppLogger.info(
      'DATA_RETENTION',
      'Dọn dẹp thành công: $stats',
    );

    return stats;
  }

  /// Tự động kiểm tra và chạy ngầm nếu chưa chạy trong 7 ngày qua
  Future<void> checkAndRunAutoRetention({
    String? userId,
    int retentionMonths = 2,
  }) async {
    final lastRun = _storage.read<int>(keyLastRetentionRun);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Chỉ tự động kiểm tra mỗi tuần 1 lần (7 ngày = 604800000 ms)
    if (lastRun != null && (now - lastRun) < 7 * 24 * 60 * 60 * 1000) {
      return;
    }

    try {
      await pruneOldData(
        userId: userId,
        retentionMonths: retentionMonths,
      );
    } catch (e) {
      AppLogger.error('DATA_RETENTION', 'Lỗi tự động dọn dẹp dữ liệu cũ: $e');
    }
  }
}
