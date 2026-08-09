import 'dart:io';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:get/get.dart';
import 'package:appintern/core/utils/logger.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';
import 'transaction_repository_base.dart';
import 'package:appintern/core/utils/logger.dart';

mixin TransactionWriteMixin on TransactionRepositoryBase, AppwriteErrorHandler {
  Future<void> _updateMonthlySummary(
    String monthYearStr,
    double incomeChange,
    double expenseChange,
  ) async {
    if (incomeChange == 0 && expenseChange == 0) return;
    final response = await appwrite.tables.listRows(
      databaseId: appwrite.databaseId,
      tableId: appwrite.monthlySummariesTableId,
      queries: [Query.equal('monthYear', monthYearStr), Query.limit(1)],
    );

    if (response.rows.isNotEmpty) {
      final doc = response.rows.first;
      double currentIncome = (doc.data['totalIncome'] ?? 0).toDouble();
      double currentExpense = (doc.data['totalExpense'] ?? 0).toDouble();

      await appwrite.tables.updateRow(
        databaseId: appwrite.databaseId,
        tableId: appwrite.monthlySummariesTableId,
        rowId: doc.$id,
        data: {
          'totalIncome': (currentIncome + incomeChange) < 0
              ? 0
              : currentIncome + incomeChange,
          'totalExpense': (currentExpense + expenseChange) < 0
              ? 0
              : currentExpense + expenseChange,
        },
      );
    } else {
      await appwrite.tables.createRow(
        databaseId: appwrite.databaseId,
        tableId: appwrite.monthlySummariesTableId,
        rowId: ID.unique(),
        data: {
          'monthYear': monthYearStr,
          'totalIncome': incomeChange < 0 ? 0 : incomeChange,
          'totalExpense': expenseChange < 0 ? 0 : expenseChange,
          'unallocatedBalance': 0.0,
        },
      );
    }
  }

  Future<TransactionModel> createTransaction({
    required TransactionModel transaction,
    required TransactionDetailModel transactionDetail,
    CategoryModel? currentCategory,
  }) async {
    final storageRepo = Get.find<StorageRepository>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    List<String> uploadedFileIds = [];

    // Upload files
    for (String path in transactionDetail.receiptFileIds) {
      if (!path.startsWith('http')) {
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

    try {
      return await handleAppwriteError(() async {
        String? createdTxId;
        String? createdDetailId;

        try {
          // 1. Tạo bản ghi Transaction
          final txResponse = await appwrite.tables.createRow(
            databaseId: appwrite.databaseId,
            tableId: appwrite.transactionsTableId,
            rowId: ID.unique(),
            data: transaction.toMap(),
          );

          createdTxId = txResponse.$id;

          // 2. Tạo bản ghi TransactionDetail
          final detailData = transactionDetail.toMap();
          detailData['receiptFileId'] = uploadedFileIds.join(',');
          detailData['transactions'] = createdTxId;

          final detailResponse = await appwrite.tables.createRow(
            databaseId: appwrite.databaseId,
            tableId: appwrite.transactionDetailsTableId,
            rowId: ID.unique(),
            data: detailData,
          );

          createdDetailId = detailResponse.$id;

          // 3. (REMOVED) Không còn cập nhật số dư Ví (Wallet Balance) ở đây

          // Định dạng tháng hiện tại (vd: "07-2026")
          String monthYearStr =
              "${transaction.transactionDate.month.toString().padLeft(2, '0')}-${transaction.transactionDate.year}";

          // 4. Cập nhật số tiền đã tiêu (MonthlyBudgets spentAmount)
          if (currentCategory != null) {
            double amountChange = transaction.type == 'EXPENSE'
                ? transaction.amount
                : -transaction.amount;

            final budgetResponse = await appwrite.tables.listRows(
              databaseId: appwrite.databaseId,
              tableId: appwrite.monthlyBudgetsTableId,
              queries: [
                Query.equal('categories', currentCategory.id),
                Query.equal('monthYear', monthYearStr),
              ],
            );

            if (budgetResponse.rows.isNotEmpty) {
              final existingBudget = budgetResponse.rows.first;
              double currentSpent = (existingBudget.data['spentAmount'] ?? 0)
                  .toDouble();
              double newSpent = currentSpent + amountChange;
              if (newSpent < 0) newSpent = 0;

              await appwrite.tables.updateRow(
                databaseId: appwrite.databaseId,
                tableId: appwrite.monthlyBudgetsTableId,
                rowId: existingBudget.$id,
                data: {'spentAmount': newSpent},
              );
            } else {
              double newSpent = amountChange;
              if (newSpent < 0) newSpent = 0;

              await appwrite.tables.createRow(
                databaseId: appwrite.databaseId,
                tableId: appwrite.monthlyBudgetsTableId,
                rowId: ID.unique(),
                data: {
                  'categories': currentCategory.id,
                  'monthYear': monthYearStr,
                  'budgetedAmount': currentCategory.defaultBudget,
                  'rolloverAmount': 0.0,
                  'spentAmount': newSpent,
                },
              );
            }
          }

          // 5. Cập nhật MonthlySummary
          double incomeChange = transaction.type == 'INCOME'
              ? transaction.amount
              : 0;
          double expenseChange = transaction.type == 'EXPENSE'
              ? transaction.amount
              : 0;
          await _updateMonthlySummary(
            monthYearStr,
            incomeChange,
            expenseChange,
          );

          transactionUpdatedController.add(null);
          return TransactionModel.fromMap(
            Map<String, dynamic>.from(txResponse.data)..['\$id'] = txResponse.$id,
          );
        } catch (e) {
          // 🚨 TỰ ĐỘNG ROLLBACK (COMPENSATING TRANSACTION) 🚨
          // Nếu có lỗi ở bước tạo Detail, Budget hoặc Summary, ta phải xóa Transaction đã tạo
          // để tránh rác Database (Orphaned records).
          try {
            if (createdDetailId != null) {
              await appwrite.tables.deleteRow(
                databaseId: appwrite.databaseId,
                tableId: appwrite.transactionDetailsTableId,
                rowId: createdDetailId,
              );
            }
            if (createdTxId != null) {
              await appwrite.tables.deleteRow(
                databaseId: appwrite.databaseId,
                tableId: appwrite.transactionsTableId,
                rowId: createdTxId,
              );
            }
          } catch (rollbackError) {
            // Lỗi trong quá trình rollback cũng cần được ghi nhận nhưng ưu tiên quăng lỗi chính
            AppLogger.error('TransactionWriteMixin', "Rollback failed: \$rollbackError");
          }
          rethrow;
        }
      });
    } catch (e) {
      for (String id in uploadedFileIds) {
        if (!transactionDetail.receiptFileIds.contains(id)) {
          try {
            await storageRepo.deleteFile(id);
          } catch (deleteError) {
            final payload = jsonEncode({'fileId': id});
            await offlineSyncService.queueTask('DELETE_ORPHANED_FILE', payload);
          }
        }
      }
      rethrow;
    }
  }

  Future<TransactionModel> createWalletAdjustmentTransaction({
    required TransactionModel transaction,
    required TransactionDetailModel transactionDetail,
  }) async {
    return handleAppwriteError(() async {
      String? createdTxId;
      String? createdDetailId;

      try {
        // 1. Tạo bản ghi Transaction (Không liên kết category)
        final txResponse = await appwrite.tables.createRow(
          databaseId: appwrite.databaseId,
          tableId: appwrite.transactionsTableId,
          rowId: ID.unique(),
          data: transaction.toMap(),
        );

        createdTxId = txResponse.$id;

        // 2. Tạo bản ghi TransactionDetail
        final detailData = transactionDetail.toMap();
        detailData['transactions'] = createdTxId;

        final detailResponse = await appwrite.tables.createRow(
          databaseId: appwrite.databaseId,
          tableId: appwrite.transactionDetailsTableId,
          rowId: ID.unique(),
          data: detailData,
        );
        createdDetailId = detailResponse.$id;

        // 5. Cập nhật MonthlySummary
        String monthYearStr =
            "${transaction.transactionDate.month.toString().padLeft(2, '0')}-${transaction.transactionDate.year}";
        double incomeChange = 0;
        double expenseChange = 0;
        if (transaction.categoryId != 'SYSTEM_ROLLOVER') {
          incomeChange = transaction.type == 'INCOME' ? transaction.amount : 0;
          expenseChange = transaction.type == 'EXPENSE'
              ? transaction.amount
              : 0;
        }
        await _updateMonthlySummary(monthYearStr, incomeChange, expenseChange);

        transactionUpdatedController.add(null);
        return TransactionModel.fromMap(
          Map<String, dynamic>.from(txResponse.data)..['\$id'] = txResponse.$id,
        );
      } catch (e) {
        try {
          if (createdDetailId != null) {
            await appwrite.tables.deleteRow(
              databaseId: appwrite.databaseId,
              tableId: appwrite.transactionDetailsTableId,
              rowId: createdDetailId,
            );
          }
          if (createdTxId != null) {
            await appwrite.tables.deleteRow(
              databaseId: appwrite.databaseId,
              tableId: appwrite.transactionsTableId,
              rowId: createdTxId,
            );
          }
        } catch (rollbackError) {
          print("Rollback failed: \$rollbackError");
        }
        rethrow;
      }
    });
  }

  Future<void> updateTransaction({
    required TransactionModel oldTransaction,
    required TransactionModel newTransaction,
    required TransactionDetailModel? newTransactionDetail,
    CategoryModel? oldCategory,
    CategoryModel? newCategory,
  }) async {
    final storageRepo = Get.find<StorageRepository>();
    final offlineSyncService = Get.find<OfflineSyncService>();
    List<String> uploadedFileIds = [];

    if (newTransactionDetail != null) {
      for (String path in newTransactionDetail.receiptFileIds) {
        if (!path.startsWith('http')) {
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

    try {
      return await handleAppwriteError(() async {
        // 3. Hoàn tác MonthlyBudgets của oldCategory
        if (oldTransaction.type == 'EXPENSE' && oldCategory != null) {
          String oldMonthYearStr =
              "${oldTransaction.transactionDate.month.toString().padLeft(2, '0')}-${oldTransaction.transactionDate.year}";
          final oldBudgetResponse = await appwrite.tables.listRows(
            databaseId: appwrite.databaseId,
            tableId: appwrite.monthlyBudgetsTableId,
            queries: [
              Query.equal('categories', oldCategory.id),
              Query.equal('monthYear', oldMonthYearStr),
            ],
          );
          if (oldBudgetResponse.rows.isNotEmpty) {
            final existingBudget = oldBudgetResponse.rows.first;
            double currentSpent = (existingBudget.data['spentAmount'] ?? 0)
                .toDouble();
            double newSpent = currentSpent - oldTransaction.amount;
            if (newSpent < 0) newSpent = 0;
            await appwrite.tables.updateRow(
              databaseId: appwrite.databaseId,
              tableId: appwrite.monthlyBudgetsTableId,
              rowId: existingBudget.$id,
              data: {'spentAmount': newSpent},
            );
          }
        }

        // 4. Áp dụng MonthlyBudgets cho newCategory
        if (newTransaction.type == 'EXPENSE' && newCategory != null) {
          String newMonthYearStr =
              "${newTransaction.transactionDate.month.toString().padLeft(2, '0')}-${newTransaction.transactionDate.year}";
          final newBudgetResponse = await appwrite.tables.listRows(
            databaseId: appwrite.databaseId,
            tableId: appwrite.monthlyBudgetsTableId,
            queries: [
              Query.equal('categories', newCategory.id),
              Query.equal('monthYear', newMonthYearStr),
            ],
          );

          if (newBudgetResponse.rows.isNotEmpty) {
            final existingBudget = newBudgetResponse.rows.first;
            double currentSpent = (existingBudget.data['spentAmount'] ?? 0)
                .toDouble();
            double newSpent = currentSpent + newTransaction.amount;
            if (newSpent < 0) newSpent = 0;
            await appwrite.tables.updateRow(
              databaseId: appwrite.databaseId,
              tableId: appwrite.monthlyBudgetsTableId,
              rowId: existingBudget.$id,
              data: {'spentAmount': newSpent},
            );
          } else {
            await appwrite.tables.createRow(
              databaseId: appwrite.databaseId,
              tableId: appwrite.monthlyBudgetsTableId,
              rowId: ID.unique(),
              data: {
                'categories': newCategory.id,
                'monthYear': newMonthYearStr,
                'budgetedAmount': newCategory.defaultBudget,
                'rolloverAmount': 0.0,
                'spentAmount': newTransaction.amount,
              },
            );
          }
        }

        // 5. Cập nhật bản ghi Transaction
        await appwrite.tables.updateRow(
          databaseId: appwrite.databaseId,
          tableId: appwrite.transactionsTableId,
          rowId: oldTransaction.id,
          data: newTransaction.toMap(),
        );

        // 6. Cập nhật bản ghi TransactionDetail
        if (newTransactionDetail != null) {
          final detailResponse = await appwrite.tables.listRows(
            databaseId: appwrite.databaseId,
            tableId: appwrite.transactionDetailsTableId,
            queries: [
              Query.equal('transactions', oldTransaction.id),
              Query.limit(1),
            ],
          );

          final detailData = newTransactionDetail.toMap();
          detailData['receiptFileId'] = uploadedFileIds.isNotEmpty
              ? uploadedFileIds.join(',')
              : newTransactionDetail.receiptFileIds.join(',');
          detailData['transactions'] = oldTransaction.id;

          if (detailResponse.rows.isNotEmpty) {
            await appwrite.tables.updateRow(
              databaseId: appwrite.databaseId,
              tableId: appwrite.transactionDetailsTableId,
              rowId: detailResponse.rows.first.$id,
              data: detailData,
            );
          } else {
            await appwrite.tables.createRow(
              databaseId: appwrite.databaseId,
              tableId: appwrite.transactionDetailsTableId,
              rowId: ID.unique(),
              data: detailData,
            );
          }
        }

        // 7. Cập nhật MonthlySummary
        String oldMonthYearStr =
            "${oldTransaction.transactionDate.month.toString().padLeft(2, '0')}-${oldTransaction.transactionDate.year}";
        String newMonthYearStr =
            "${newTransaction.transactionDate.month.toString().padLeft(2, '0')}-${newTransaction.transactionDate.year}";

        if (oldMonthYearStr == newMonthYearStr) {
          double incomeChange =
              (newTransaction.type == 'INCOME' ? newTransaction.amount : 0) -
              (oldTransaction.type == 'INCOME' ? oldTransaction.amount : 0);
          double expenseChange =
              (newTransaction.type == 'EXPENSE' ? newTransaction.amount : 0) -
              (oldTransaction.type == 'EXPENSE' ? oldTransaction.amount : 0);
          await _updateMonthlySummary(
            oldMonthYearStr,
            incomeChange,
            expenseChange,
          );
        } else {
          double oldIncomeChange = oldTransaction.type == 'INCOME'
              ? -oldTransaction.amount
              : 0;
          double oldExpenseChange = oldTransaction.type == 'EXPENSE'
              ? -oldTransaction.amount
              : 0;
          await _updateMonthlySummary(
            oldMonthYearStr,
            oldIncomeChange,
            oldExpenseChange,
          );

          double newIncomeChange = newTransaction.type == 'INCOME'
              ? newTransaction.amount
              : 0;
          double newExpenseChange = newTransaction.type == 'EXPENSE'
              ? newTransaction.amount
              : 0;
          await _updateMonthlySummary(
            newMonthYearStr,
            newIncomeChange,
            newExpenseChange,
          );
        }
        transactionUpdatedController.add(null);
      });
    } catch (e) {
      if (newTransactionDetail != null) {
        for (String id in uploadedFileIds) {
          if (!newTransactionDetail.receiptFileIds.contains(id)) {
            try {
              await storageRepo.deleteFile(id);
            } catch (deleteError) {
              final payload = jsonEncode({'fileId': id});
              await offlineSyncService.queueTask(
                'DELETE_ORPHANED_FILE',
                payload,
              );
            }
          }
        }
      }
      rethrow;
    }
  }

  Future<void> updateWalletAdjustmentTransaction({
    required TransactionModel oldTransaction,
    required TransactionModel newTransaction,
    required TransactionDetailModel? newTransactionDetail,
  }) async {
    return handleAppwriteError(() async {
      await appwrite.tables.updateRow(
        databaseId: appwrite.databaseId,
        tableId: appwrite.transactionsTableId,
        rowId: oldTransaction.id,
        data: newTransaction.toMap(),
      );

      if (newTransactionDetail != null) {
        final detailResponse = await appwrite.tables.listRows(
          databaseId: appwrite.databaseId,
          tableId: appwrite.transactionDetailsTableId,
          queries: [
            Query.equal('transactions', oldTransaction.id),
            Query.limit(1),
          ],
        );

        final detailData = newTransactionDetail.toMap();
        detailData['transactions'] = oldTransaction.id;

        if (detailResponse.rows.isNotEmpty) {
          await appwrite.tables.updateRow(
            databaseId: appwrite.databaseId,
            tableId: appwrite.transactionDetailsTableId,
            rowId: detailResponse.rows.first.$id,
            data: detailData,
          );
        } else {
          await appwrite.tables.createRow(
            databaseId: appwrite.databaseId,
            tableId: appwrite.transactionDetailsTableId,
            rowId: ID.unique(),
            data: detailData,
          );
        }
      }

      String oldMonthYearStr =
          "${oldTransaction.transactionDate.month.toString().padLeft(2, '0')}-${oldTransaction.transactionDate.year}";
      String newMonthYearStr =
          "${newTransaction.transactionDate.month.toString().padLeft(2, '0')}-${newTransaction.transactionDate.year}";

      if (newTransaction.categoryId != 'SYSTEM_ROLLOVER' &&
          oldTransaction.categoryId != 'SYSTEM_ROLLOVER') {
        if (oldMonthYearStr == newMonthYearStr) {
          double incomeChange =
              (newTransaction.type == 'INCOME' ? newTransaction.amount : 0) -
              (oldTransaction.type == 'INCOME' ? oldTransaction.amount : 0);
          double expenseChange =
              (newTransaction.type == 'EXPENSE' ? newTransaction.amount : 0) -
              (oldTransaction.type == 'EXPENSE' ? oldTransaction.amount : 0);
          await _updateMonthlySummary(
            oldMonthYearStr,
            incomeChange,
            expenseChange,
          );
        } else {
          double oldIncomeChange = oldTransaction.type == 'INCOME'
              ? -oldTransaction.amount
              : 0;
          double oldExpenseChange = oldTransaction.type == 'EXPENSE'
              ? -oldTransaction.amount
              : 0;
          await _updateMonthlySummary(
            oldMonthYearStr,
            oldIncomeChange,
            oldExpenseChange,
          );

          double newIncomeChange = newTransaction.type == 'INCOME'
              ? newTransaction.amount
              : 0;
          double newExpenseChange = newTransaction.type == 'EXPENSE'
              ? newTransaction.amount
              : 0;
          await _updateMonthlySummary(
            newMonthYearStr,
            newIncomeChange,
            newExpenseChange,
          );
        }
      }

      transactionUpdatedController.add(null);
    });
  }

  Future<void> deleteTransaction({
    required TransactionModel transaction,
    CategoryModel? currentCategory,
  }) async {
    return handleAppwriteError(() async {
      if (transaction.type == 'EXPENSE' && currentCategory != null) {
        String monthYearStr =
            "${transaction.transactionDate.month.toString().padLeft(2, '0')}-${transaction.transactionDate.year}";

        final budgetResponse = await appwrite.tables.listRows(
          databaseId: appwrite.databaseId,
          tableId: appwrite.monthlyBudgetsTableId,
          queries: [
            Query.equal('categories', currentCategory.id),
            Query.equal('monthYear', monthYearStr),
          ],
        );

        if (budgetResponse.rows.isNotEmpty) {
          final existingBudget = budgetResponse.rows.first;
          double currentSpent = (existingBudget.data['spentAmount'] ?? 0)
              .toDouble();
          double newSpent = currentSpent - transaction.amount;
          if (newSpent < 0) newSpent = 0;

          await appwrite.tables.updateRow(
            databaseId: appwrite.databaseId,
            tableId: appwrite.monthlyBudgetsTableId,
            rowId: existingBudget.$id,
            data: {'spentAmount': newSpent},
          );
        }
      }

      await appwrite.tables.updateRow(
        databaseId: appwrite.databaseId,
        tableId: appwrite.transactionsTableId,
        rowId: transaction.id,
        data: {'status': 'DELETED'},
      );

      String monthYearStr =
          "${transaction.transactionDate.month.toString().padLeft(2, '0')}-${transaction.transactionDate.year}";
      double incomeChange = 0;
      double expenseChange = 0;
      if (transaction.categoryId != 'SYSTEM_ROLLOVER') {
        incomeChange = transaction.type == 'INCOME' ? -transaction.amount : 0;
        expenseChange = transaction.type == 'EXPENSE' ? -transaction.amount : 0;
      }
      await _updateMonthlySummary(monthYearStr, incomeChange, expenseChange);

      transactionUpdatedController.add(null);
    });
  }
}
