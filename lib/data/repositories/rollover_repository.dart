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
      final currentBudgets = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlyBudgetsTableId,
        queries: [
          Query.equal('monthYear', currentMonthStr),
          Query.limit(1), // Chỉ cần tìm thấy 1 dòng là biết đã khởi tạo
        ],
      );

      if (currentBudgets.documents.isNotEmpty) {
        return RolloverStateResult(RolloverState.noPending);
      }

      // 2. Tìm tháng gần nhất có dữ liệu (để xem là Normal, Gap hay New Account)
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      final prevMonthStr =
          "${prevMonth.month.toString().padLeft(2, '0')}-${prevMonth.year}";

      final prevBudgets = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.equal('monthYear', prevMonthStr), Query.limit(1)],
      );

      if (prevBudgets.documents.isNotEmpty) {
        return RolloverStateResult(
          RolloverState.normalRollover,
          lastActiveMonthYear: prevMonthStr,
        );
      }

      // 3. Nếu không có tháng trước, thử tìm xem có BẤT KỲ budget nào trong lịch sử không
      final anyHistory = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.limit(1)],
      );

      if (anyHistory.documents.isNotEmpty) {
        return RolloverStateResult(RolloverState.multiMonthGap);
      }

      return RolloverStateResult(RolloverState.newAccount);
    });
  }

  Future<RolloverData> getRolloverData(String userId, String monthYear) async {
    return handleAppwriteError(() async {
      // 1. Fetch Summary
      final summaryResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlySummariesTableId,
        queries: [Query.equal('monthYear', monthYear), Query.limit(1)],
      );

      MonthlySummaryModel? summary;
      if (summaryResponse.documents.isNotEmpty) {
        final summaryDoc = summaryResponse.documents.first;
        summary = MonthlySummaryModel.fromMap(
          Map<String, dynamic>.from(summaryDoc.data)..['\$id'] = summaryDoc.$id,
        );
      }

      // 2. Fetch Budgets
      final budgetsResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.equal('monthYear', monthYear)],
      );

      List<MonthlyBudgetModel> budgets = budgetsResponse.documents
          .map(
            (doc) => MonthlyBudgetModel.fromMap(
              Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
            ),
          )
          .toList();

      // 3. Fetch Categories (Document Security tự lọc theo user)
      final typesResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTypeTableId,
      );

      final typeIds = typesResponse.documents.map((doc) => doc.$id).toList();
      List<CategoryModel> categories = [];
      if (typeIds.isNotEmpty) {
        for (String typeId in typeIds) {
          final cats = await _appwrite.databases.listDocuments(
            databaseId: _appwrite.databaseId,
            collectionId: _appwrite.categoriesTableId,
            queries: [Query.equal('categoryTypes', typeId)],
          );
          categories.addAll(
            cats.documents
                .map(
                  (doc) => CategoryModel.fromMap(
                    Map<String, dynamic>.from(doc.data)..['\$id'] = doc.$id,
                  ),
                )
                .toList(),
          );
        }
      }

      // 4. (REMOVED) Fetch Wallets cho Total Wallet Balance
      double totalWalletBalance = 0.0;

      return RolloverData(
        summary: summary,
        budgets: budgets,
        categories: categories,
        totalWalletBalance: totalWalletBalance,
      );
    });
  }

  Future<void> executeHardReset(
    String userId, {
    Set<String> goalCategoryIds = const {},
  }) async {
    return handleAppwriteError(() async {
      final now = DateTime.now();
      final currentMonthStr =
          "${now.month.toString().padLeft(2, '0')}-${now.year}";

      final typesResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTypeTableId,
      );

      final typeIds = typesResponse.documents.map((doc) => doc.$id).toList();
      if (typeIds.isEmpty) return;

      List<dynamic> categories = [];
      for (String typeId in typeIds) {
        final cats = await _appwrite.databases.listDocuments(
          databaseId: _appwrite.databaseId,
          collectionId: _appwrite.categoriesTableId,
          queries: [Query.equal('categoryTypes', typeId)],
        );
        categories.addAll(cats.documents);
      }

      for (var catDoc in categories) {
        final catId = catDoc.$id;
        final bool isGoal = goalCategoryIds.contains(catId);

        await _appwrite.databases.createDocument(
          databaseId: _appwrite.databaseId,
          collectionId: _appwrite.monthlyBudgetsTableId,
          documentId: ID.unique(),
          data: {
            'categories': catId,
            'monthYear': currentMonthStr,
            // Goal categories luôn có budgetedAmount = 0 (tiền nằm ở rollover)
            'budgetedAmount': isGoal ? 0.0 : 0.0,
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
    Map<String, double> rolloverAmounts, {
    Set<String> goalCategoryIds = const {},
  }) async {
    return handleAppwriteError(() async {
      final now = DateTime.now();
      final currentMonthStr =
          "${now.month.toString().padLeft(2, '0')}-${now.year}";

      final typesResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.categoriesTypeTableId,
      );

      final typeIds = typesResponse.documents.map((doc) => doc.$id).toList();
      if (typeIds.isEmpty) return;

      List<dynamic> categories = [];
      for (String typeId in typeIds) {
        final cats = await _appwrite.databases.listDocuments(
          databaseId: _appwrite.databaseId,
          collectionId: _appwrite.categoriesTableId,
          queries: [Query.equal('categoryTypes', typeId)],
        );
        categories.addAll(cats.documents);
      }

      for (var catDoc in categories) {
        final catId = catDoc.$id;
        final bool isGoal = goalCategoryIds.contains(catId);

        // Goal categories: budgetedAmount luôn = 0, tiền nằm ở rolloverAmount
        // Expense categories: lấy từ updatedBudgets (user đã sửa) hoặc defaultBudget
        final defaultBudget = isGoal
            ? 0.0
            : (updatedBudgets[catId] ??
                (catDoc.data['defaultBudget'] ?? 0).toDouble());

        final rolloverAmt = rolloverAmounts[catId] ?? 0.0;

        await _appwrite.databases.createDocument(
          databaseId: _appwrite.databaseId,
          collectionId: _appwrite.monthlyBudgetsTableId,
          documentId: ID.unique(),
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

      // 4. Xóa tất cả giao dịch trong tháng đó
      final txResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.transactionsTableId,
        queries: [
          Query.between('transactionDate', startIso, endIso),
          Query.limit(500),
        ],
      );

      for (var doc in txResponse.documents) {
        await _appwrite.databases
            .deleteDocument(
              databaseId: _appwrite.databaseId,
              collectionId: _appwrite.transactionsTableId,
              documentId: doc.$id,
            )
            .catchError((_) => null);
      }

      // 5. Xóa tất cả ngân sách tháng (monthlybudgets) trong tháng đó
      final budgetsResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlyBudgetsTableId,
        queries: [Query.equal('monthYear', monthYear), Query.limit(500)],
      );
      for (var doc in budgetsResponse.documents) {
        await _appwrite.databases
            .deleteDocument(
              databaseId: _appwrite.databaseId,
              collectionId: _appwrite.monthlyBudgetsTableId,
              documentId: doc.$id,
            )
            .catchError((_) => null);
      }

      // 6. Xóa tất cả báo cáo tháng (monthlysummaries) trong tháng đó
      final summariesResponse = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.monthlySummariesTableId,
        queries: [Query.equal('monthYear', monthYear), Query.limit(500)],
      );
      for (var doc in summariesResponse.documents) {
        await _appwrite.databases
            .deleteDocument(
              databaseId: _appwrite.databaseId,
              collectionId: _appwrite.monthlySummariesTableId,
              documentId: doc.$id,
            )
            .catchError((_) => null);
      }
    });
  }
}
