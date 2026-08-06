import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/data/models/monthly_summary_model.dart';
import 'package:appintern/data/models/monthly_budget_model.dart';
import 'package:appintern/data/models/category_model.dart';

enum RolloverState { noPending, normalRollover, multiMonthGap, newAccount }

class RolloverStateResult {
  final RolloverState state;
  final String? lastActiveMonthYear;

  RolloverStateResult(this.state, {this.lastActiveMonthYear});
}

class RolloverData {
  final MonthlySummaryModel? summary;
  final List<MonthlyBudgetModel> budgets;
  final List<CategoryModel> categories;
  final double totalWalletBalance;

  RolloverData({
    required this.summary,
    required this.budgets,
    required this.categories,
    required this.totalWalletBalance,
  });
}

class RolloverRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;

  RolloverRepository(this._appwrite);

  Future<RolloverStateResult> checkRolloverState() async {
    return handleAppwriteError(() async {
      final now = DateTime.now();
      final currentMonthStr =
          "${now.month.toString().padLeft(2, '0')}-${now.year}";

      // 1. Kiểm tra tháng hiện tại đã khởi tạo chưa
      final currentBudgets = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlyBudgetsTableId,
        queries: [
          Query.equal('monthYear', currentMonthStr),
          Query.limit(1), // Chỉ cần tìm thấy 1 dòng là biết đã khởi tạo
        ],
      );

      if (currentBudgets.rows.isNotEmpty) {
        return RolloverStateResult(RolloverState.noPending);
      }

      // 2. Tìm tháng gần nhất có dữ liệu (để xem là Normal, Gap hay New Account)
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      final prevMonthStr =
          "${prevMonth.month.toString().padLeft(2, '0')}-${prevMonth.year}";

      final prevBudgets = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.equal('monthYear', prevMonthStr), Query.limit(1)],
      );

      if (prevBudgets.rows.isNotEmpty) {
        return RolloverStateResult(
          RolloverState.normalRollover,
          lastActiveMonthYear: prevMonthStr,
        );
      }

      // 3. Nếu không có tháng trước, thử tìm xem có BẤT KỲ budget nào trong lịch sử không
      final anyHistory = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.limit(1)],
      );

      if (anyHistory.rows.isNotEmpty) {
        return RolloverStateResult(RolloverState.multiMonthGap);
      }

      return RolloverStateResult(RolloverState.newAccount);
    });
  }

  Future<RolloverData> getRolloverData(String userId, String monthYear) async {
    return handleAppwriteError(() async {
      // 1. Fetch Summary
      final summaryResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlySummariesTableId,
        queries: [Query.equal('monthYear', monthYear), Query.limit(1)],
      );

      MonthlySummaryModel? summary;
      if (summaryResponse.rows.isNotEmpty) {
        final summaryRow = summaryResponse.rows.first;
        summary = MonthlySummaryModel.fromMap(
          Map<String, dynamic>.from(summaryRow.data)..['\$id'] = summaryRow.$id,
        );
      }

      // 2. Fetch Budgets
      final budgetsResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.equal('monthYear', monthYear)],
      );

      List<MonthlyBudgetModel> budgets = budgetsResponse.rows
          .map(
            (r) => MonthlyBudgetModel.fromMap(
              Map<String, dynamic>.from(r.data)..['\$id'] = r.$id,
            ),
          )
          .toList();

      // 3. Fetch Categories
      final typesResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTypeTableId,
        queries: [Query.equal('ownerId', userId)],
      );

      final typeIds = typesResponse.rows.map((r) => r.$id).toList();
      List<CategoryModel> categories = [];
      if (typeIds.isNotEmpty) {
        for (String typeId in typeIds) {
          final cats = await _appwrite.tables.listRows(
            databaseId: _appwrite.databaseId,
            tableId: _appwrite.categoriesTableId,
            queries: [Query.equal('categoryTypes', typeId)],
          );
          categories.addAll(
            cats.rows
                .map(
                  (r) => CategoryModel.fromMap(
                    Map<String, dynamic>.from(r.data)..['\$id'] = r.$id,
                  ),
                )
                .toList(),
          );
        }
      }

      // 4. (REMOVED) Fetch Wallets cho Total Wallet Balance
      // Vì đã xóa bảng wallets, chúng ta sẽ để totalWalletBalance là 0.0
      // Controller sẽ lấy số dư thực tế từ BudgetService thay thế.
      double totalWalletBalance = 0.0;

      return RolloverData(
        summary: summary,
        budgets: budgets,
        categories: categories,
        totalWalletBalance: totalWalletBalance,
      );
    });
  }

  Future<void> executeHardReset(String userId) async {
    return handleAppwriteError(() async {
      final now = DateTime.now();
      final currentMonthStr =
          "${now.month.toString().padLeft(2, '0')}-${now.year}";

      final typesResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTypeTableId,
        queries: [Query.equal('ownerId', userId)],
      );

      final typeIds = typesResponse.rows.map((r) => r.$id).toList();
      if (typeIds.isEmpty) return;

      List<dynamic> categories = [];
      for (String typeId in typeIds) {
        final cats = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.categoriesTableId,
          queries: [Query.equal('categoryTypes', typeId)],
        );
        categories.addAll(cats.rows);
      }

      for (var catRow in categories) {
        final catId = catRow.$id;

        // Cố tình không lấy defaultBudget mà gán bằng 0.0
        // Để tổng phân bổ là 0, và Chưa phân bổ không bị âm.
        await _appwrite.tables.createRow(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.monthlyBudgetsTableId,
          rowId: ID.unique(),
          data: {
            'categories': catId,
            'monthYear': currentMonthStr,
            'budgetedAmount': 0.0,
            'rolloverAmount': 0.0,
            'spentAmount': 0.0,
          },
        );
      }
    });
  }

  Future<void> executeRollover(
    String userId,
    Map<String, double> updatedBudgets,
    Map<String, double> rolloverAmounts,
  ) async {
    return handleAppwriteError(() async {
      final now = DateTime.now();
      final currentMonthStr =
          "${now.month.toString().padLeft(2, '0')}-${now.year}";

      final typesResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.categoriesTypeTableId,
        queries: [Query.equal('ownerId', userId)],
      );

      final typeIds = typesResponse.rows.map((r) => r.$id).toList();
      if (typeIds.isEmpty) return;

      List<dynamic> categories = [];
      for (String typeId in typeIds) {
        final cats = await _appwrite.tables.listRows(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.categoriesTableId,
          queries: [Query.equal('categoryTypes', typeId)],
        );
        categories.addAll(cats.rows);
      }

      for (var catRow in categories) {
        final catId = catRow.$id;
        // Lấy từ updatedBudgets (user đã sửa) hoặc mặc định.
        final defaultBudget =
            updatedBudgets[catId] ??
            (catRow.data['defaultBudget'] ?? 0).toDouble();

        final rolloverAmt = rolloverAmounts[catId] ?? 0.0;

        await _appwrite.tables.createRow(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.monthlyBudgetsTableId,
          rowId: ID.unique(),
          data: {
            'categories': catId,
            'monthYear': currentMonthStr,
            'budgetedAmount': defaultBudget,
            'rolloverAmount': rolloverAmt,
            'spentAmount': 0.0,
          },
        );
      }
    });
  }

  Future<void> clearMonthData(String monthYear) async {
    return handleAppwriteError(() async {
      // 1. Phân tích monthYear (MM-yyyy) để lấy khoảng thời gian
      final parts = monthYear.split('-');
      if (parts.length != 2)
        throw Exception("Định dạng tháng năm không hợp lệ");
      final month = int.parse(parts[0]);
      final year = int.parse(parts[1]);

      final start = DateTime(year, month, 1);
      final end = DateTime(
        year,
        month + 1,
        1,
      ).subtract(const Duration(milliseconds: 1));

      final startIso = start.toIso8601String();
      final endIso = end.toIso8601String();

      // 2 & 3. (REMOVED) Không cần hoàn tác số dư ví trong DB nữa
      // Vì bảng wallets giờ chỉ lưu số dư ban đầu, Tổng ngân sách được tính tự động.

      // 4. Xóa tất cả giao dịch trong tháng đó
      // Chúng ta vẫn cần query giao dịch ra để xóa
      final txResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.transactionsTableId,
        queries: [
          Query.between('transactionDate', startIso, endIso),
          Query.limit(500),
        ],
      );

      for (var doc in txResponse.rows) {
        await _appwrite.tables
            .deleteRow(
              databaseId: _appwrite.databaseId,
              tableId: _appwrite.transactionsTableId,
              rowId: doc.$id,
            )
            .catchError((_) => null);
      }

      // 5. Xóa tất cả ngân sách tháng (monthlybudgets) trong tháng đó
      final budgetsResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.equal('monthYear', monthYear), Query.limit(500)],
      );
      for (var doc in budgetsResponse.rows) {
        await _appwrite.tables
            .deleteRow(
              databaseId: _appwrite.databaseId,
              tableId: _appwrite.monthlyBudgetsTableId,
              rowId: doc.$id,
            )
            .catchError((_) => null);
      }

      // 6. Xóa tất cả báo cáo tháng (monthlysummaries) trong tháng đó
      final summariesResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlySummariesTableId,
        queries: [Query.equal('monthYear', monthYear), Query.limit(500)],
      );
      for (var doc in summariesResponse.rows) {
        await _appwrite.tables
            .deleteRow(
              databaseId: _appwrite.databaseId,
              tableId: _appwrite.monthlySummariesTableId,
              rowId: doc.$id,
            )
            .catchError((_) => null);
      }
    });
  }
}
