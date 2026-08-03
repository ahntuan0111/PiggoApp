import 'dart:async';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';
import 'transaction/transaction_repository_base.dart';
import 'transaction/transaction_read_mixin.dart';
import 'transaction/transaction_write_mixin.dart';
import 'transaction/transaction_cache_mixin.dart';

class TransactionRepository extends TransactionRepositoryBase
    with
        AppwriteErrorHandler,
        TransactionReadMixin,
        TransactionWriteMixin,
        TransactionCacheMixin {
  TransactionRepository(AppwriteService appwrite) : super(appwrite);

  Stream<void> get onTransactionUpdated => transactionUpdatedController.stream;
}
