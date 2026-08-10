import 'package:appwrite/appwrite.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';
import 'package:get/get.dart';
import 'package:appintern/core/services/network_service.dart';
import 'transaction_repository_base.dart';

mixin TransactionReadMixin on TransactionRepositoryBase, AppwriteErrorHandler {
  Future<List<Map<String, dynamic>>> getHistoryByCategory(
    String categoryId, {
    int limit = 5,
    DateTime? start,
    DateTime? end,
  }) async {
    final network = Get.find<NetworkService>();
    if (network.isOffline.value) {
      if (start != null) {
        String monthYearStr =
            "${start.month.toString().padLeft(2, '0')}-${start.year}";
        final cachedTxs = await localDb.getTransactionsByMonth(monthYearStr);
        final filtered = cachedTxs
            .where((tx) => tx.categoryId == categoryId)
            .toList();
        filtered.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
        final limited = filtered.take(limit).toList();
        return limited
            .map((tx) => {'transaction': tx, 'detail': null})
            .toList();
      }
      return [];
    }

    return handleAppwriteError(() async {
      List<String> queries = [
        Query.equal('categories', categoryId),
        Query.notEqual('status', 'DELETED'),
        Query.orderDesc('transactionDate'),
        Query.limit(limit),
      ];

      if (start != null) {
        queries.add(
          Query.greaterThanEqual('transactionDate', start.toIso8601String()),
        );
      }
      if (end != null) {
        queries.add(
          Query.lessThanEqual('transactionDate', end.toIso8601String()),
        );
      }

      // 1. Fetch transactions by categoryId
      final response = await appwrite.databases.listDocuments(
        databaseId: appwrite.databaseId,
        collectionId: appwrite.transactionsTableId,
        queries: queries,
      );

      if (response.documents.isEmpty) return [];

      final txIds = response.documents.map((doc) => doc.$id).toList();

      // 2. Batch fetch details
      final detailsResponse = await appwrite.databases.listDocuments(
        databaseId: appwrite.databaseId,
        collectionId: appwrite.transactionDetailsTableId,
        queries: [
          Query.equal('transactions', txIds),
          Query.limit(txIds.length),
        ],
      );

      final Map<String, TransactionDetailModel> detailMap = {};
      for (var doc in detailsResponse.documents) {
        final detail = TransactionDetailModel.fromMap(
          Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
        );
        final txData = doc.data['transactions'];
        String? linkedTxId;
        if (txData is Map) {
          linkedTxId = txData['\$id'];
        } else if (txData is String) {
          linkedTxId = txData;
        }
        if (linkedTxId != null) {
          detailMap[linkedTxId] = detail;
        }
      }

      List<Map<String, dynamic>> results = response.documents.map((doc) {
        final tx = TransactionModel.fromMap(
          Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
        );
        return {'transaction': tx, 'detail': detailMap[tx.id]};
      }).toList();

      return results;
    });
  }

  Future<List<Map<String, dynamic>>> getRecentHistory({
    int limit = 10,
    DateTime? start,
    DateTime? end,
  }) async {
    final network = Get.find<NetworkService>();
    if (network.isOffline.value) {
      if (start != null) {
        String monthYearStr =
            "${start.month.toString().padLeft(2, '0')}-${start.year}";
        final cachedTxs = await localDb.getTransactionsByMonth(monthYearStr);
        cachedTxs.sort(
          (a, b) => b.transactionDate.compareTo(a.transactionDate),
        );
        final limited = cachedTxs.take(limit).toList();
        return limited
            .map((tx) => {'transaction': tx, 'detail': null})
            .toList();
      }
      return [];
    }

    return handleAppwriteError(() async {
      List<String> queries = [
        Query.notEqual('status', 'DELETED'),
        Query.orderDesc('transactionDate'),
        Query.limit(limit),
      ];

      if (start != null) {
        queries.add(
          Query.greaterThanEqual('transactionDate', start.toIso8601String()),
        );
      }
      if (end != null) {
        queries.add(
          Query.lessThanEqual('transactionDate', end.toIso8601String()),
        );
      }

      final response = await appwrite.databases.listDocuments(
        databaseId: appwrite.databaseId,
        collectionId: appwrite.transactionsTableId,
        queries: queries,
      );

      if (response.documents.isEmpty) return [];

      final txIds = response.documents.map((doc) => doc.$id).toList();

      final detailsResponse = await appwrite.databases.listDocuments(
        databaseId: appwrite.databaseId,
        collectionId: appwrite.transactionDetailsTableId,
        queries: [
          Query.equal('transactions', txIds),
          Query.limit(txIds.length),
        ],
      );

      final Map<String, TransactionDetailModel> detailMap = {};
      for (var doc in detailsResponse.documents) {
        final detail = TransactionDetailModel.fromMap(
          Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
        );
        final txData = doc.data['transactions'];
        String? linkedTxId;
        if (txData is Map) {
          linkedTxId = txData['\$id'];
        } else if (txData is String) {
          linkedTxId = txData;
        }
        if (linkedTxId != null) {
          detailMap[linkedTxId] = detail;
        }
      }

      List<Map<String, dynamic>> results = response.documents.map((doc) {
        final tx = TransactionModel.fromMap(
          Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
        );
        return {'transaction': tx, 'detail': detailMap[tx.id]};
      }).toList();

      final models = results
          .map((e) => e['transaction'] as TransactionModel)
          .toList();
      if (models.isNotEmpty) await localDb.saveTransactions(models);

      return results;
    });
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
    final network = Get.find<NetworkService>();
    if (network.isOffline.value) {
      if (start != null) {
        String monthYearStr =
            "${start.month.toString().padLeft(2, '0')}-${start.year}";
        final cachedTxs = await localDb.getTransactionsByMonth(monthYearStr);

        var filtered = cachedTxs;
        if (categoryId != null && categoryId.isNotEmpty) {
          filtered = filtered
              .where((tx) => tx.categoryId == categoryId)
              .toList();
        }
        if (type != null && type.isNotEmpty) {
          filtered = filtered.where((tx) => tx.type == type).toList();
        }

        if (ascending) {
          filtered.sort(
            (a, b) => a.transactionDate.compareTo(b.transactionDate),
          );
        } else {
          filtered.sort(
            (a, b) => b.transactionDate.compareTo(a.transactionDate),
          );
        }

        return filtered
            .map((tx) => {'transaction': tx, 'detail': null})
            .toList();
      }
      return [];
    }

    return handleAppwriteError(() async {
      List<String> queries = [Query.notEqual('status', 'DELETED')];

      if (start != null) {
        queries.add(
          Query.greaterThanEqual('transactionDate', start.toIso8601String()),
        );
      }
      if (end != null) {
        queries.add(
          Query.lessThanEqual('transactionDate', end.toIso8601String()),
        );
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        queries.add(Query.equal('categories', categoryId));
      }
      if (type != null && type.isNotEmpty) {
        queries.add(Query.equal('type', type));
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        queries.add(Query.search('note', searchQuery.trim()));
      }

      if (ascending) {
        queries.add(Query.orderAsc('transactionDate'));
      } else {
        queries.add(Query.orderDesc('transactionDate'));
      }

      queries.add(Query.limit(limit));

      if (cursorAfter != null && cursorAfter.isNotEmpty) {
        queries.add(Query.cursorAfter(cursorAfter));
      }

      final response = await appwrite.databases.listDocuments(
        databaseId: appwrite.databaseId,
        collectionId: appwrite.transactionsTableId,
        queries: queries,
      );

      if (response.documents.isEmpty) return [];

      final txIds = response.documents.map((doc) => doc.$id).toList();

      final detailsResponse = await appwrite.databases.listDocuments(
        databaseId: appwrite.databaseId,
        collectionId: appwrite.transactionDetailsTableId,
        queries: [
          Query.equal('transactions', txIds),
          Query.limit(txIds.length),
        ],
      );

      final Map<String, TransactionDetailModel> detailMap = {};
      for (var doc in detailsResponse.documents) {
        final detail = TransactionDetailModel.fromMap(
          Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
        );
        final txData = doc.data['transactions'];
        String? linkedTxId;
        if (txData is Map) {
          linkedTxId = txData['\$id'];
        } else if (txData is String) {
          linkedTxId = txData;
        }
        if (linkedTxId != null) {
          detailMap[linkedTxId] = detail;
        }
      }

      List<Map<String, dynamic>> results = response.documents.map((doc) {
        final tx = TransactionModel.fromMap(
          Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
        );
        return {'transaction': tx, 'detail': detailMap[tx.id]};
      }).toList();

      final models = results
          .map((e) => e['transaction'] as TransactionModel)
          .toList();
      if (models.isNotEmpty) await localDb.saveTransactions(models);

      return results;
    });
  }

  Future<TransactionModel?> getTransactionById(String transactionId) async {
    final network = Get.find<NetworkService>();
    if (network.isOffline.value) {
      // Offline fallback: find in all local transactions
      return await localDb.getTransactionById(transactionId);
    }

    return handleAppwriteError(() async {
      final response = await appwrite.databases.getDocument(
        databaseId: appwrite.databaseId,
        collectionId: appwrite.transactionsTableId,
        documentId: transactionId,
      );
      return TransactionModel.fromMap(
        Map<String, dynamic>.from(response.data)..['\$id'] = response.$id,
      );
    });
  }

  Future<TransactionDetailModel?> getTransactionDetail(
    String transactionId,
  ) async {
    final network = Get.find<NetworkService>();
    if (network.isOffline.value) {
      // Offline fallback: return null if not in cache (currently no detail cache)
      // Actually we can check offline queue for pending CREATE/UPDATE to get detail,
      // but returning null is safe enough for offline read.
      return null;
    }

    return handleAppwriteError(() async {
      final response = await appwrite.databases.listDocuments(
        databaseId: appwrite.databaseId,
        collectionId: appwrite.transactionDetailsTableId,
        queries: [Query.equal('transactions', transactionId), Query.limit(1)],
      );

      if (response.documents.isNotEmpty) {
        final doc = response.documents.first;
        return TransactionDetailModel.fromMap(
          Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
        );
      }
      return null;
    });
  }
}
