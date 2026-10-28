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
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    List<TransactionModel> txs;

    if (start != null && end != null) {
      txs = await localDb.getTransactionsByDateRange(start, end);
    } else if (start != null) {
      String monthYearStr =
          "${start.month.toString().padLeft(2, '0')}-${start.year}";
      txs = await localDb.getTransactionsByMonth(monthYearStr);
    } else {
      txs = await localDb.getAllTransactions();
    }

    final filtered = txs.where((tx) => tx.categoryId == categoryId).toList();
    filtered.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    final limited = filtered.take(limit).toList();

    final List<Map<String, dynamic>> results = [];
    for (final tx in limited) {
      final detail = await localDb.getTransactionDetail(tx.id);
      results.add({'transaction': tx, 'detail': detail});
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> getRecentHistory({
    int limit = 10,
    DateTime? start,
    DateTime? end,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    List<TransactionModel> txs;

    if (start != null && end != null) {
      txs = await localDb.getTransactionsByDateRange(start, end);
    } else if (start != null) {
      String monthYearStr =
          "${start.month.toString().padLeft(2, '0')}-${start.year}";
      txs = await localDb.getTransactionsByMonth(monthYearStr);
    } else {
      txs = await localDb.getAllTransactions();
    }

    txs.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    final limited = txs.take(limit).toList();

    final List<Map<String, dynamic>> results = [];
    for (final tx in limited) {
      final detail = await localDb.getTransactionDetail(tx.id);
      results.add({'transaction': tx, 'detail': detail});
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> getTransactionsByFilters({
    DateTime? start,
    DateTime? end,
    String? categoryId,
    String? type,
    String? searchQuery,
    int limit = 20,
    String? cursorAfter,
    bool ascending = false,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    List<TransactionModel> txs;

    if (start != null && end != null) {
      txs = await localDb.getTransactionsByDateRange(start, end);
    } else if (start != null) {
      String monthYearStr =
          "${start.month.toString().padLeft(2, '0')}-${start.year}";
      txs = await localDb.getTransactionsByMonth(monthYearStr);
    } else {
      txs = await localDb.getAllTransactions();
    }

    var filtered = txs;
    if (categoryId != null && categoryId.isNotEmpty) {
      filtered = filtered.where((tx) => tx.categoryId == categoryId).toList();
    }
    if (type != null && type.isNotEmpty) {
      filtered = filtered.where((tx) => tx.type == type).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final queryLower = searchQuery.trim().toLowerCase();
      filtered = filtered
          .where((tx) => (tx.note ?? '').toLowerCase().contains(queryLower))
          .toList();
    }

    if (ascending) {
      filtered.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    } else {
      filtered.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    }

    if (cursorAfter != null && cursorAfter.isNotEmpty) {
      final index = filtered.indexWhere((tx) => tx.id == cursorAfter);
      if (index != -1) {
        filtered = filtered.skip(index + 1).toList();
      }
    }

    final limited = filtered.take(limit).toList();
    final List<Map<String, dynamic>> results = [];
    for (final tx in limited) {
      final detail = await localDb.getTransactionDetail(tx.id);
      results.add({'transaction': tx, 'detail': detail});
    }
    return results;
  }

  Future<TransactionModel?> getTransactionById(String transactionId) async {
    final localDb = Get.find<LocalDatabaseService>();
    return await localDb.getTransactionById(transactionId);
  }

  Future<TransactionDetailModel?> getTransactionDetail(
    String transactionId,
  ) async {
    final localDb = Get.find<LocalDatabaseService>();
    return await localDb.getTransactionDetail(transactionId);
  }
}
