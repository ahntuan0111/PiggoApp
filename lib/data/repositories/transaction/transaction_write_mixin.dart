import 'dart:io';
import 'package:get/get.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'transaction_repository_base.dart';

mixin TransactionWriteMixin on TransactionRepositoryBase {
  Future<TransactionModel> createTransaction({
    required TransactionModel transaction,
    required TransactionDetailModel transactionDetail,
    CategoryModel? currentCategory,
    String? userId,
  }) async {
    final storageRepo = Get.find<StorageRepository>();
    List<String> uploadedFileIds = [];

    // Lưu các file ảnh biên lai local qua StorageRepository
    for (String path in transactionDetail.receiptFileIds) {
      if (!path.startsWith('http') && File(path).existsSync()) {
        try {
          String fileId = await storageRepo.uploadReceiptImage(File(path));
          uploadedFileIds.add(fileId);
        } catch (e) {
          rethrow;
        }
      } else {
        uploadedFileIds.add(path);
      }
    }

    final localDb = Get.find<LocalDatabaseService>();
    final txToInsert = transaction.id.isEmpty
        ? TransactionModel(
            id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
            categoryId: transaction.categoryId,
            amount: transaction.amount,
            type: transaction.type,
            transactionDate: transaction.transactionDate,
            status: transaction.status,
            note: transaction.note,
            updatedAt: transaction.updatedAt,
          )
        : transaction;

    final detailToInsert = TransactionDetailModel(
      id: transactionDetail.id.isNotEmpty
          ? transactionDetail.id
          : '${txToInsert.id}_detail',
      transactionId: txToInsert.id,
      note: transactionDetail.note,
      receiptFileIds: uploadedFileIds,
      rawInputText: transactionDetail.rawInputText,
      confidenceScore: transactionDetail.confidenceScore,
    );

    await localDb.insertTransactionAtomic(txToInsert, detail: detailToInsert);
    transactionUpdatedController.add(null);
    return txToInsert;
  }

  Future<TransactionModel> createWalletAdjustmentTransaction({
    required TransactionModel transaction,
    required TransactionDetailModel transactionDetail,
    String? userId,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    final txToInsert = transaction.id.isEmpty
        ? TransactionModel(
            id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
            categoryId: transaction.categoryId,
            amount: transaction.amount,
            type: transaction.type,
            transactionDate: transaction.transactionDate,
            status: transaction.status,
            note: transaction.note,
            updatedAt: transaction.updatedAt,
          )
        : transaction;

    await localDb.insertTransactionAtomic(
      txToInsert,
      detail: transactionDetail,
    );
    transactionUpdatedController.add(null);
    return txToInsert;
  }

  Future<void> updateTransaction({
    required TransactionModel oldTransaction,
    required TransactionModel newTransaction,
    required TransactionDetailModel? newTransactionDetail,
    CategoryModel? oldCategory,
    CategoryModel? newCategory,
  }) async {
    final storageRepo = Get.find<StorageRepository>();
    List<String> uploadedFileIds = [];

    if (newTransactionDetail != null) {
      for (String path in newTransactionDetail.receiptFileIds) {
        if (!path.startsWith('http') && File(path).existsSync()) {
          try {
            String fileId = await storageRepo.uploadReceiptImage(File(path));
            uploadedFileIds.add(fileId);
          } catch (e) {
            rethrow;
          }
        } else {
          uploadedFileIds.add(path);
        }
      }
    }

    final detailToUpdate = newTransactionDetail != null
        ? TransactionDetailModel(
            id: newTransactionDetail.id.isNotEmpty
                ? newTransactionDetail.id
                : '${newTransaction.id}_detail',
            transactionId: newTransaction.id,
            note: newTransactionDetail.note,
            receiptFileIds: uploadedFileIds,
            rawInputText: newTransactionDetail.rawInputText,
            confidenceScore: newTransactionDetail.confidenceScore,
          )
        : null;

    final localDb = Get.find<LocalDatabaseService>();
    await localDb.updateTransactionAtomic(
      newTransaction,
      detail: detailToUpdate,
    );
    transactionUpdatedController.add(null);
  }

  Future<void> updateWalletAdjustmentTransaction({
    required TransactionModel oldTransaction,
    required TransactionModel newTransaction,
    required TransactionDetailModel? newTransactionDetail,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    await localDb.updateTransactionAtomic(
      newTransaction,
      detail: newTransactionDetail,
    );
    transactionUpdatedController.add(null);
  }

  Future<void> deleteTransaction({
    required TransactionModel transaction,
    CategoryModel? currentCategory,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    await localDb.deleteTransactionAtomic(transaction.id);
    transactionUpdatedController.add(null);
  }
}
