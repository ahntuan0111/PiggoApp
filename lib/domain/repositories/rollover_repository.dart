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
        summary = MonthlySummaryModel.fromMap(summaryResponse.rows.first.data);
      }

      // 2. Fetch Budgets
      final budgetsResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.equal('monthYear', monthYear)],
      );

      List<MonthlyBudgetModel> budgets = budgetsResponse.rows
          .map((r) => MonthlyBudgetModel.fromMap(r.data))
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
            cats.rows.map((r) => CategoryModel.fromMap(r.data)).toList(),
          );
        }
      }

      // 4. Fetch Wallets cho Total Wallet Balance
      final walletsResponse = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.walletsTableId,
        queries: [Query.equal('ownerId', userId)],
      );
      double totalWalletBalance = walletsResponse.rows.fold(
        0.0,
        (sum, w) => sum + (w.data['balance'] ?? 0).toDouble(),
      );

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
        final defaultBudget = (catRow.data['defaultBudget'] ?? 0).toDouble();

        await _appwrite.tables.createRow(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.monthlyBudgetsTableId,
          rowId: ID.unique(),
          data: {
            'categories': catId,
            'monthYear': currentMonthStr,
            'budgetedAmount': defaultBudget,
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
  ) async {
    // Tạm thời MVP: giống hệt HardReset nhưng thay budgetedAmount bằng mức ngân sách do user duyệt/AI đề xuất.
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

        await _appwrite.tables.createRow(
          databaseId: _appwrite.databaseId,
          tableId: _appwrite.monthlyBudgetsTableId,
          rowId: ID.unique(),
          data: {
            'categories': catId,
            'monthYear': currentMonthStr,
            'budgetedAmount': defaultBudget,
            'rolloverAmount': 0.0,
            'spentAmount': 0.0,
          },
        );
      }
    });
  }
}
