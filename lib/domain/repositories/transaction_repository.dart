import 'package:appwrite/appwrite.dart';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/wallet_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'dart:async';

class TransactionRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;

  // Rule 2C: Sử dụng Stream từ Repository để báo hiệu thay đổi dữ liệu
  final StreamController<void> _transactionUpdatedController =
      StreamController<void>.broadcast();
  Stream<void> get onTransactionUpdated => _transactionUpdatedController.stream;

  TransactionRepository(this._appwrite);

  Future<void> _updateMonthlySummary(String monthYearStr, double incomeChange, double expenseChange) async {
    if (incomeChange == 0 && expenseChange == 0) return;
    final response = await _appwrite.tables.listRows(
      databaseId: _appwrite.databaseId,
      tableId: _appwrite.monthlySummariesTableId,
      queries: [Query.equal('monthYear', monthYearStr), Query.limit(1)],
    );

    if (response.rows.isNotEmpty) {
      final doc = response.rows.first;
      double currentIncome = (doc.data['totalIncome'] ?? 0).toDouble();
      double currentExpense = (doc.data['totalExpense'] ?? 0).toDouble();
      
      await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlySummariesTableId,
        rowId: doc.$id,
        data: {
          'totalIncome': (currentIncome + incomeChange) < 0 ? 0 : currentIncome + incomeChange,
          'totalExpense': (currentExpense + expenseChange) < 0 ? 0 : currentExpense + expenseChange,
        },
      );
    } else {
      await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlySummariesTableId,
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

  Future<void> createTransaction({
    required TransactionModel transaction,
    required TransactionDetailModel transactionDetail,
    required WalletModel currentWallet,
    required CategoryModel currentCategory,
  }) async {
    return handleAppwriteError(() async {
      // 1. Tạo bản ghi Transaction
      final txResponse = await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionsTableId,
        rowId: ID.unique(),
        data: transaction.toMap(),
      );

      final newTxId = txResponse.$id;

      // 2. Tạo bản ghi TransactionDetail
      final detailData = transactionDetail.toMap();
      detailData['transactions'] =
          newTxId; // Sử dụng đúng tên Relationship là 'transactions'

      await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionDetailsTableId,
        rowId: ID.unique(),
        data: detailData,
      );

      // 3. Cập nhật số dư Ví (Wallet Balance)
      double newBalance = currentWallet.balance;
      if (transaction.type == 'INCOME') {
        newBalance += transaction.amount;
      } else {
        newBalance -= transaction.amount;
      }

      await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.walletsTableId,
        rowId: currentWallet.id,
        data: {'balance': newBalance},
      );

      // 4. Cập nhật số tiền đã tiêu (MonthlyBudgets spentAmount)
      double amountChange = transaction.type == 'EXPENSE'
          ? transaction.amount
          : -transaction.amount;

      // Định dạng tháng hiện tại (vd: "07-2026")
      String monthYearStr =
          "${transaction.transactionDate.month.toString().padLeft(2, '0')}-${transaction.transactionDate.year}";

      // Thử tìm MonthlyBudget của category này trong tháng
      final budgetResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlyBudgetsTableId,
        queries: [
          Query.equal('categories', currentCategory.id),
          Query.equal('monthYear', monthYearStr),
        ],
      );

      if (budgetResponse.rows.isNotEmpty) {
        // Đã có budget -> Cập nhật spentAmount
        final existingBudget = budgetResponse.rows.first;
        double currentSpent = (existingBudget.data['spentAmount'] ?? 0)
            .toDouble();
        double newSpent = currentSpent + amountChange;
        if (newSpent < 0) newSpent = 0;

        await _appwrite.tables.updateRow(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.monthlyBudgetsTableId,
          rowId: existingBudget.$id,
          data: {'spentAmount': newSpent},
        );
      } else {
        // Chưa có budget -> Tạo mới
        double newSpent = amountChange;
        if (newSpent < 0) newSpent = 0;

        await _appwrite.tables.createRow(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.monthlyBudgetsTableId,
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

      // 5. Cập nhật MonthlySummary
      double incomeChange = transaction.type == 'INCOME' ? transaction.amount : 0;
      double expenseChange = transaction.type == 'EXPENSE' ? transaction.amount : 0;
      await _updateMonthlySummary(monthYearStr, incomeChange, expenseChange);

      // Thông báo cho các Controller đang lắng nghe (HomeController) cập nhật lại UI
      _transactionUpdatedController.add(null);
    });
  }

  Future<void> createWalletAdjustmentTransaction({
    required TransactionModel transaction,
    required TransactionDetailModel transactionDetail,
    required WalletModel currentWallet,
  }) async {
    return handleAppwriteError(() async {
      // 1. Tạo bản ghi Transaction (Không liên kết category)
      final txResponse = await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionsTableId,
        rowId: ID.unique(),
        data: transaction.toMap(),
      );

      final newTxId = txResponse.$id;

      // 2. Tạo bản ghi TransactionDetail
      final detailData = transactionDetail.toMap();
      detailData['transactions'] = newTxId;

      await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionDetailsTableId,
        rowId: ID.unique(),
        data: detailData,
      );

      // 3. Cập nhật số dư Ví (Wallet Balance)
      double newBalance = currentWallet.balance;
      if (transaction.type == 'INCOME') {
        newBalance += transaction.amount;
      } else {
        newBalance -= transaction.amount;
      }

      await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.walletsTableId,
        rowId: currentWallet.id,
        data: {'balance': newBalance},
      );

      // 4. Bỏ qua MonthlyBudgets vì đây là dòng tiền Unallocated

      // 5. Cập nhật MonthlySummary
      String monthYearStr = "${transaction.transactionDate.month.toString().padLeft(2, '0')}-${transaction.transactionDate.year}";
      double incomeChange = transaction.type == 'INCOME' ? transaction.amount : 0;
      double expenseChange = transaction.type == 'EXPENSE' ? transaction.amount : 0;
      await _updateMonthlySummary(monthYearStr, incomeChange, expenseChange);

      // Thông báo cập nhật
      _transactionUpdatedController.add(null);
    });
  }

  Future<void> updateTransaction({
    required TransactionModel oldTransaction,
    required TransactionModel newTransaction,
    required TransactionDetailModel? newTransactionDetail,
    required WalletModel oldWallet,
    required WalletModel newWallet,
    CategoryModel? oldCategory,
    CategoryModel? newCategory,
  }) async {
    return handleAppwriteError(() async {
      // 1. Hoàn tác tác động của oldTransaction lên oldWallet
      double oldWalletBalance = oldWallet.balance;
      if (oldTransaction.type == 'INCOME') {
        oldWalletBalance -= oldTransaction.amount;
      } else {
        oldWalletBalance += oldTransaction.amount;
      }

      // 2. Tính số dư mới cho newWallet (xử lý ví cũ vs ví mới)
      if (oldWallet.id == newWallet.id) {
        double finalBalance = oldWalletBalance;
        if (newTransaction.type == 'INCOME') {
          finalBalance += newTransaction.amount;
        } else {
          finalBalance -= newTransaction.amount;
        }
        await _appwrite.tables.updateRow(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.walletsTableId,
          rowId: newWallet.id,
          data: {'balance': finalBalance},
        );
      } else {
        // Cập nhật ví cũ
        await _appwrite.tables.updateRow(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.walletsTableId,
          rowId: oldWallet.id,
          data: {'balance': oldWalletBalance},
        );
        // Cập nhật ví mới
        double newWalletBalance = newWallet.balance;
        if (newTransaction.type == 'INCOME') {
          newWalletBalance += newTransaction.amount;
        } else {
          newWalletBalance -= newTransaction.amount;
        }
        await _appwrite.tables.updateRow(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.walletsTableId,
          rowId: newWallet.id,
          data: {'balance': newWalletBalance},
        );
      }

      // 3. Hoàn tác MonthlyBudgets của oldCategory
      if (oldTransaction.type == 'EXPENSE' && oldCategory != null) {
        String oldMonthYearStr =
            "${oldTransaction.transactionDate.month.toString().padLeft(2, '0')}-${oldTransaction.transactionDate.year}";
        final oldBudgetResponse = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.monthlyBudgetsTableId,
          queries: [
            Query.equal('categories', oldCategory.id),
            Query.equal('monthYear', oldMonthYearStr),
          ],
        );
        if (oldBudgetResponse.rows.isNotEmpty) {
          final existingBudget = oldBudgetResponse.rows.first;
          double currentSpent =
              (existingBudget.data['spentAmount'] ?? 0).toDouble();
          double newSpent = currentSpent - oldTransaction.amount;
          if (newSpent < 0) newSpent = 0;
          await _appwrite.tables.updateRow(
            databaseId: _appwrite.databaseId,
            tableId: _appwrite.monthlyBudgetsTableId,
            rowId: existingBudget.$id,
            data: {'spentAmount': newSpent},
          );
        }
      }

      // 4. Áp dụng MonthlyBudgets cho newCategory
      if (newTransaction.type == 'EXPENSE' && newCategory != null) {
        String newMonthYearStr =
            "${newTransaction.transactionDate.month.toString().padLeft(2, '0')}-${newTransaction.transactionDate.year}";
        final newBudgetResponse = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.monthlyBudgetsTableId,
          queries: [
            Query.equal('categories', newCategory.id),
            Query.equal('monthYear', newMonthYearStr),
          ],
        );

        if (newBudgetResponse.rows.isNotEmpty) {
          final existingBudget = newBudgetResponse.rows.first;
          double currentSpent =
              (existingBudget.data['spentAmount'] ?? 0).toDouble();
          double newSpent = currentSpent + newTransaction.amount;
          if (newSpent < 0) newSpent = 0;
          await _appwrite.tables.updateRow(
            databaseId: _appwrite.databaseId,
            tableId: _appwrite.monthlyBudgetsTableId,
            rowId: existingBudget.$id,
            data: {'spentAmount': newSpent},
          );
        } else {
          await _appwrite.tables.createRow(
            databaseId: _appwrite.databaseId,
            tableId: _appwrite.monthlyBudgetsTableId,
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
      await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionsTableId,
        rowId: oldTransaction.id,
        data: newTransaction.toMap(),
      );

      // 6. Cập nhật bản ghi TransactionDetail (nếu có)
      if (newTransactionDetail != null) {
        final detailResponse = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.transactionDetailsTableId,
          queries: [
            Query.equal('transactions', oldTransaction.id),
            Query.limit(1),
          ],
        );

        final detailData = newTransactionDetail.toMap();
        detailData['transactions'] = oldTransaction.id;

        if (detailResponse.rows.isNotEmpty) {
          await _appwrite.tables.updateRow(
            databaseId: _appwrite.databaseId,
            tableId: _appwrite.transactionDetailsTableId,
            rowId: detailResponse.rows.first.$id,
            data: detailData,
          );
        } else {
          await _appwrite.tables.createRow(
            databaseId: _appwrite.databaseId,
            tableId: _appwrite.transactionDetailsTableId,
            rowId: ID.unique(),
            data: detailData,
          );
        }
      }

      // 7. Cập nhật MonthlySummary
      String oldMonthYearStr = "${oldTransaction.transactionDate.month.toString().padLeft(2, '0')}-${oldTransaction.transactionDate.year}";
      String newMonthYearStr = "${newTransaction.transactionDate.month.toString().padLeft(2, '0')}-${newTransaction.transactionDate.year}";
      
      if (oldMonthYearStr == newMonthYearStr) {
        double incomeChange = (newTransaction.type == 'INCOME' ? newTransaction.amount : 0) - (oldTransaction.type == 'INCOME' ? oldTransaction.amount : 0);
        double expenseChange = (newTransaction.type == 'EXPENSE' ? newTransaction.amount : 0) - (oldTransaction.type == 'EXPENSE' ? oldTransaction.amount : 0);
        await _updateMonthlySummary(oldMonthYearStr, incomeChange, expenseChange);
      } else {
        double oldIncomeChange = oldTransaction.type == 'INCOME' ? -oldTransaction.amount : 0;
        double oldExpenseChange = oldTransaction.type == 'EXPENSE' ? -oldTransaction.amount : 0;
        await _updateMonthlySummary(oldMonthYearStr, oldIncomeChange, oldExpenseChange);

        double newIncomeChange = newTransaction.type == 'INCOME' ? newTransaction.amount : 0;
        double newExpenseChange = newTransaction.type == 'EXPENSE' ? newTransaction.amount : 0;
        await _updateMonthlySummary(newMonthYearStr, newIncomeChange, newExpenseChange);
      }

      _transactionUpdatedController.add(null);
    });
  }

  Future<void> updateWalletAdjustmentTransaction({
    required TransactionModel oldTransaction,
    required TransactionModel newTransaction,
    required TransactionDetailModel? newTransactionDetail,
    required WalletModel currentWallet,
  }) async {
    return handleAppwriteError(() async {
      // 1. Hoàn tác số dư ví cũ
      double balance = currentWallet.balance;
      if (oldTransaction.type == 'INCOME') {
        balance -= oldTransaction.amount;
      } else {
        balance += oldTransaction.amount;
      }

      // 2. Áp dụng số dư mới
      if (newTransaction.type == 'INCOME') {
        balance += newTransaction.amount;
      } else {
        balance -= newTransaction.amount;
      }

      await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.walletsTableId,
        rowId: currentWallet.id,
        data: {'balance': balance},
      );

      // 3. Cập nhật Transaction
      await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionsTableId,
        rowId: oldTransaction.id,
        data: newTransaction.toMap(),
      );

      // 4. Cập nhật TransactionDetail
      if (newTransactionDetail != null) {
        final detailResponse = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.transactionDetailsTableId,
          queries: [
            Query.equal('transactions', oldTransaction.id),
            Query.limit(1),
          ],
        );

        final detailData = newTransactionDetail.toMap();
        detailData['transactions'] = oldTransaction.id;

        if (detailResponse.rows.isNotEmpty) {
          await _appwrite.tables.updateRow(
            databaseId: _appwrite.databaseId,
            tableId: _appwrite.transactionDetailsTableId,
            rowId: detailResponse.rows.first.$id,
            data: detailData,
          );
        } else {
          await _appwrite.tables.createRow(
            databaseId: _appwrite.databaseId,
            tableId: _appwrite.transactionDetailsTableId,
            rowId: ID.unique(),
            data: detailData,
          );
        }
      }

      // 5. Cập nhật MonthlySummary
      String oldMonthYearStr = "${oldTransaction.transactionDate.month.toString().padLeft(2, '0')}-${oldTransaction.transactionDate.year}";
      String newMonthYearStr = "${newTransaction.transactionDate.month.toString().padLeft(2, '0')}-${newTransaction.transactionDate.year}";
      
      if (oldMonthYearStr == newMonthYearStr) {
        double incomeChange = (newTransaction.type == 'INCOME' ? newTransaction.amount : 0) - (oldTransaction.type == 'INCOME' ? oldTransaction.amount : 0);
        double expenseChange = (newTransaction.type == 'EXPENSE' ? newTransaction.amount : 0) - (oldTransaction.type == 'EXPENSE' ? oldTransaction.amount : 0);
        await _updateMonthlySummary(oldMonthYearStr, incomeChange, expenseChange);
      } else {
        double oldIncomeChange = oldTransaction.type == 'INCOME' ? -oldTransaction.amount : 0;
        double oldExpenseChange = oldTransaction.type == 'EXPENSE' ? -oldTransaction.amount : 0;
        await _updateMonthlySummary(oldMonthYearStr, oldIncomeChange, oldExpenseChange);

        double newIncomeChange = newTransaction.type == 'INCOME' ? newTransaction.amount : 0;
        double newExpenseChange = newTransaction.type == 'EXPENSE' ? newTransaction.amount : 0;
        await _updateMonthlySummary(newMonthYearStr, newIncomeChange, newExpenseChange);
      }

      _transactionUpdatedController.add(null);
    });
  }

  Future<List<Map<String, dynamic>>> getHistoryByCategory(
    String categoryId, {
    int limit = 5,
  }) async {
    return handleAppwriteError(() async {
      // 1. Fetch transactions by categoryId
      final response = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionsTableId,
        queries: [
          Query.equal('categories', categoryId),
          Query.notEqual('status', 'DELETED'),
          Query.orderDesc('transactionDate'),
          Query.limit(limit),
        ],
      );

      List<Map<String, dynamic>> results = [];

      // 2. Fetch details cho từng transaction
      // Do limit = 5 nên việc query trong vòng lặp (hoặc Future.wait) là chấp nhận được.
      final futures = response.rows.map((row) async {
        final tx = TransactionModel.fromMap(row.data);

        final detailResponse = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.transactionDetailsTableId,
          queries: [Query.equal('transactions', tx.id), Query.limit(1)],
        );

        TransactionDetailModel? detail;
        if (detailResponse.rows.isNotEmpty) {
          detail = TransactionDetailModel.fromMap(
            detailResponse.rows.first.data,
          );
        }

        return {'transaction': tx, 'detail': detail};
      });

      results = await Future.wait(futures);

      // Sắp xếp lại vì Future.wait có thể làm mất thứ tự
      results.sort((a, b) {
        final txA = a['transaction'] as TransactionModel;
        final txB = b['transaction'] as TransactionModel;
        return txB.transactionDate.compareTo(txA.transactionDate);
      });

      return results;
    });
  }

  Future<List<Map<String, dynamic>>> getHistoryByWallets(
    List<String> walletIds, {
    int limit = 10,
  }) async {
    return handleAppwriteError(() async {
      if (walletIds.isEmpty) return [];

      final response = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionsTableId,
        queries: [
          Query.equal('wallets', walletIds),
          Query.notEqual('status', 'DELETED'),
          Query.orderDesc('transactionDate'),
          Query.limit(limit),
        ],
      );

      List<Map<String, dynamic>> results = [];

      final futures = response.rows.map((row) async {
        final tx = TransactionModel.fromMap(row.data);

        final detailResponse = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.transactionDetailsTableId,
          queries: [Query.equal('transactions', tx.id), Query.limit(1)],
        );

        TransactionDetailModel? detail;
        if (detailResponse.rows.isNotEmpty) {
          detail = TransactionDetailModel.fromMap(
            detailResponse.rows.first.data,
          );
        }

        return {'transaction': tx, 'detail': detail};
      });

      results = await Future.wait(futures);

      results.sort((a, b) {
        final txA = a['transaction'] as TransactionModel;
        final txB = b['transaction'] as TransactionModel;
        return txB.transactionDate.compareTo(txA.transactionDate);
      });

      return results;
    });
  }

  Future<List<Map<String, dynamic>>> getTransactionsByWalletsAndFilters({
    required List<String> walletIds,
    DateTime? start,
    DateTime? end,
    String? categoryId,
    String? type,
    String? searchQuery,
    int limit = 20,
    String? cursorAfter,
    bool ascending = false,
  }) async {
    return handleAppwriteError(() async {
      if (walletIds.isEmpty) return [];

      List<String> queries = [
        Query.equal('wallets', walletIds),
        Query.notEqual('status', 'DELETED'),
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

      final response = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionsTableId,
        queries: queries,
      );

      List<Map<String, dynamic>> results = [];

      final futures = response.rows.map((row) async {
        final tx = TransactionModel.fromMap(row.data);

        // Fetch detail if needed, or if we denormalized note, we might not even need detail for the list!
        // But let's fetch it anyway for completeness (or receipts)
        final detailResponse = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.transactionDetailsTableId,
          queries: [Query.equal('transactions', tx.id), Query.limit(1)],
        );

        TransactionDetailModel? detail;
        if (detailResponse.rows.isNotEmpty) {
          detail = TransactionDetailModel.fromMap(
            detailResponse.rows.first.data,
          );
        }

        return {'transaction': tx, 'detail': detail};
      });

      results = await Future.wait(futures);

      // Do not re-sort locally because it breaks pagination across pages.
      // Appwrite already returned them sorted by transactionDate!
      return results;
    });
  }

  Future<TransactionModel?> getTransactionById(String transactionId) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.getRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionsTableId,
        rowId: transactionId,
      );
      return TransactionModel.fromMap(response.data);
    });
  }

  Future<TransactionDetailModel?> getTransactionDetail(String transactionId) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionDetailsTableId,
        queries: [
          Query.equal('transactions', transactionId),
          Query.limit(1),
        ],
      );

      if (response.rows.isNotEmpty) {
        return TransactionDetailModel.fromMap(response.rows.first.data);
      }
      return null;
    });
  }

  Future<void> deleteTransaction({
    required TransactionModel transaction,
    required WalletModel currentWallet,
    CategoryModel? currentCategory,
  }) async {
    return handleAppwriteError(() async {
      // 1. Cập nhật số dư Ví
      double newBalance = currentWallet.balance;
      if (transaction.type == 'INCOME') {
        newBalance -= transaction.amount;
      } else {
        newBalance += transaction.amount;
      }

      await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.walletsTableId,
        rowId: currentWallet.id,
        data: {'balance': newBalance},
      );

      // 2. Cập nhật Budget (Chỉ dành cho Outflow)
      if (transaction.type == 'EXPENSE' && currentCategory != null) {
        String monthYearStr =
            "${transaction.transactionDate.month.toString().padLeft(2, '0')}-${transaction.transactionDate.year}";

        final budgetResponse = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.monthlyBudgetsTableId,
          queries: [
            Query.equal('categories', currentCategory.id),
            Query.equal('monthYear', monthYearStr),
          ],
        );

        if (budgetResponse.rows.isNotEmpty) {
          final existingBudget = budgetResponse.rows.first;
          double currentSpent =
              (existingBudget.data['spentAmount'] ?? 0).toDouble();
          double newSpent = currentSpent - transaction.amount;
          if (newSpent < 0) newSpent = 0;

          await _appwrite.tables.updateRow(
            databaseId: _appwrite.databaseId,
            tableId: _appwrite.monthlyBudgetsTableId,
            rowId: existingBudget.$id,
            data: {'spentAmount': newSpent},
          );
        }
      }

      // 3. Soft Delete Transaction
      await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionsTableId,
        rowId: transaction.id,
        data: {'status': 'DELETED'},
      );

      // 4. Cập nhật MonthlySummary
      String monthYearStr = "${transaction.transactionDate.month.toString().padLeft(2, '0')}-${transaction.transactionDate.year}";
      double incomeChange = transaction.type == 'INCOME' ? -transaction.amount : 0;
      double expenseChange = transaction.type == 'EXPENSE' ? -transaction.amount : 0;
      await _updateMonthlySummary(monthYearStr, incomeChange, expenseChange);

      _transactionUpdatedController.add(null);
    });
  }
}
