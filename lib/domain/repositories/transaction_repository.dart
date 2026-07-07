import 'package:appwrite/appwrite.dart';
import 'package:appintern/core/network/appwrite_service.dart';
import 'package:appintern/domain/repositories/appwrite_error_mixin.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/wallet_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'dart:async';

class TransactionRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;
  
  // Rule 2C: Sử dụng Stream từ Repository để báo hiệu thay đổi dữ liệu
  final StreamController<void> _transactionUpdatedController = StreamController<void>.broadcast();
  Stream<void> get onTransactionUpdated => _transactionUpdatedController.stream;

  TransactionRepository(this._appwrite);

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
      detailData['transactions'] = newTxId; // Sử dụng đúng tên Relationship là 'transactions'

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
      double amountChange = transaction.type == 'EXPENSE' ? transaction.amount : -transaction.amount;
      
      // Định dạng tháng hiện tại (vd: "07-2026")
      String monthYearStr = "${transaction.transactionDate.month.toString().padLeft(2, '0')}-${transaction.transactionDate.year}";

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
        double currentSpent = (existingBudget.data['spentAmount'] ?? 0).toDouble();
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

      // Thông báo cho các Controller đang lắng nghe (HomeController) cập nhật lại UI
      _transactionUpdatedController.add(null);
    });
  }
}
