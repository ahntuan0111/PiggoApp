import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/core/errors/exceptions.dart';
import 'transaction_repository_base.dart';

mixin TransactionCacheMixin on TransactionRepositoryBase {
  Future<List<TransactionModel>> getCachedTransactionsByMonth(
    String monthYearStr,
  ) async {
    try {
      return await localDb.getTransactionsByMonth(monthYearStr);
    } catch (e) {
      throw CacheException("Lỗi đọc cache LocalDatabase: $e");
    }
  }

  Future<void> saveTransactionsToCache(List<TransactionModel> txs) async {
    try {
      await localDb.saveTransactions(txs);
    } catch (e) {
      throw CacheException("Lỗi lưu cache LocalDatabase: $e");
    }
  }
}
