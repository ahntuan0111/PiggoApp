import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:get/get.dart';
import 'transaction_repository_base.dart';

mixin TransactionReadMixin on TransactionRepositoryBase {
  Future<List<Map<String, dynamic>>> getHistoryByCategory(
    String categoryId, {
    int limit = 5,
    DateTime? start,
    DateTime? end,
    String? userId,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    DateTime? effectiveStart = start;
    DateTime? effectiveEnd = end;

    if (start != null && end == null) {
      effectiveStart = DateTime(start.year, start.month, 1);
      effectiveEnd = DateTime(start.year, start.month + 1, 0, 23, 59, 59, 999);
    }

    return await localDb.getTransactionsWithDetailsAndCategory(
      userId: userId,
      categoryId: categoryId,
      start: effectiveStart,
      end: effectiveEnd,
      limit: limit,
      ascending: false,
    );
  }

  Future<List<Map<String, dynamic>>> getRecentHistory({
    int limit = 10,
    DateTime? start,
    DateTime? end,
    String? userId,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    DateTime? effectiveStart = start;
    DateTime? effectiveEnd = end;

    if (start != null && end == null) {
      effectiveStart = DateTime(start.year, start.month, 1);
      effectiveEnd = DateTime(start.year, start.month + 1, 0, 23, 59, 59, 999);
    }

    return await localDb.getTransactionsWithDetailsAndCategory(
      userId: userId,
      start: effectiveStart,
      end: effectiveEnd,
      limit: limit,
      ascending: false,
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionsByFilters({
    DateTime? start,
    DateTime? end,
    String? categoryId,
    String? type,
    String? searchQuery,
    int limit = 20,
    int offset = 0,
    String? cursorAfter,
    bool ascending = false,
    String? userId,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    DateTime? effectiveStart = start;
    DateTime? effectiveEnd = end;

    if (start != null && end == null) {
      effectiveStart = DateTime(start.year, start.month, 1);
      effectiveEnd = DateTime(start.year, start.month + 1, 0, 23, 59, 59, 999);
    }

    return await localDb.getTransactionsWithDetailsAndCategory(
      userId: userId,
      categoryId: categoryId,
      type: type,
      searchQuery: searchQuery,
      start: effectiveStart,
      end: effectiveEnd,
      limit: limit,
      offset: offset,
      cursorAfter: cursorAfter,
      ascending: ascending,
    );
  }

  Future<TransactionModel?> getTransactionById(
    String transactionId, {
    String? userId,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    return await localDb.getTransactionById(transactionId, userId: userId);
  }

  Future<TransactionDetailModel?> getTransactionDetail(
    String transactionId,
  ) async {
    final localDb = Get.find<LocalDatabaseService>();
    return await localDb.getTransactionDetail(transactionId);
  }
}
