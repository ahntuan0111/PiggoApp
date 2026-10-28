import 'dart:async';
import 'transaction/transaction_repository_base.dart';
import 'transaction/transaction_read_mixin.dart';
import 'transaction/transaction_write_mixin.dart';
import 'transaction/transaction_cache_mixin.dart';

class TransactionRepository extends TransactionRepositoryBase
    with
        TransactionReadMixin,
        TransactionWriteMixin,
        TransactionCacheMixin {
  TransactionRepository() : super();

  Stream<void> get onTransactionUpdated => transactionUpdatedController.stream;
}
