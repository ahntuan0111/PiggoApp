import 'dart:convert';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:get/get.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';

class StatisticsRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;

  StatisticsRepository(this._appwrite);

  Future<Map<String, dynamic>> getOnlineStatistics(String timeframe) async {
    final storage = Get.find<StorageService>();
    final userId = storage.read(AppKeys.userId) ?? '';

    return handleAppwriteError(() async {
      final response = await _appwrite.functions.createExecution(
        functionId: _appwrite.functionStatisticsInsight,
        body: jsonEncode({'timeframe': timeframe, 'userId': userId}),
        xasync: false,
      );

      if (response.responseStatusCode != 200) {
        throw Exception('Lỗi Server: ${response.responseStatusCode}');
      }

      final responseBody = jsonDecode(response.responseBody);
      if (responseBody['success'] == true) {
        return responseBody['data'];
      } else {
        throw Exception(
          responseBody['message'] ?? 'Lỗi không xác định từ Server',
        );
      }
    });
  }

  Future<bool> hasAnyTransactions() async {
    final localDb = Get.find<LocalDatabaseService>();
    return await localDb.hasAnyTransactions();
  }

  Future<Map<String, dynamic>> getOfflineStatistics(String timeframe) async {
    final localDb = Get.find<LocalDatabaseService>();
    final now = DateTime.now();

    // 1. Xác định mốc thời gian
    DateTime startDate = DateTime(now.year, now.month, now.day);
    if (timeframe == 'last_7_days') {
      startDate = startDate.subtract(const Duration(days: 7));
    } else if (timeframe == 'this_month') {
      startDate = DateTime(now.year, now.month, 1);
    } else if (timeframe == '3_months') {
      startDate = DateTime(now.year, now.month - 2, 1);
    } else if (timeframe == '6_months') {
      startDate = DateTime(now.year, now.month - 5, 1);
    }

    // 2. Lấy dữ liệu
    final transactions = await localDb.getTransactionsByDateRange(
      startDate,
      now,
    );
    final categories = await localDb.getCategories();

    final currentMonthYear =
        '${now.month.toString().padLeft(2, '0')}-${now.year}';
    final budgets = await localDb.getMonthlyBudgets(currentMonthYear);

    // Map Category
    final Map<String, Map<String, dynamic>> categoriesMap = {};
    for (var cat in categories) {
      categoriesMap[cat['id']] = cat;
    }

    // 3. Tính ngân sách
    double totalBudget = 0;
    for (var budget in budgets) {
      totalBudget +=
          (budget['budgetedAmount'] ?? 0) + (budget['rolloverAmount'] ?? 0);
    }

    // 4. Gom nhóm
    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, Map<String, dynamic>> expenseByCategory = {};
    Map<String, Map<String, dynamic>> trendByDate = {};

    bool isMonthlyTrend = timeframe == '3_months' || timeframe == '6_months';

    for (var tx in transactions) {
      final amount = tx.amount;
      final isExpense = tx.type == 'EXPENSE';

      if (isExpense) {
        totalExpense += amount;

        final cid = tx.categoryId;
        if (!expenseByCategory.containsKey(cid)) {
          expenseByCategory[cid] = {
            'id': cid,
            'amount': 0.0,
            'name': categoriesMap[cid]?['name'] ?? 'Khác',
            'color': categoriesMap[cid]?['color'] ?? '#9E9E9E',
            'icon':
                categoriesMap[cid]?['iconName'] ?? 'assets/icons/others.png',
          };
        }
        expenseByCategory[cid]!['amount'] += amount;
      } else {
        totalIncome += amount;
      }

      // Trend
      String dateKey;
      if (isMonthlyTrend) {
        dateKey = 'Tháng ${tx.transactionDate.month}';
      } else {
        dateKey =
            '${tx.transactionDate.day.toString().padLeft(2, '0')}/${tx.transactionDate.month.toString().padLeft(2, '0')}';
      }

      if (!trendByDate.containsKey(dateKey)) {
        trendByDate[dateKey] = {
          'income': 0.0,
          'expense': 0.0,
          'sortKey': tx.transactionDate.millisecondsSinceEpoch,
        };
      }
      if (isExpense) {
        trendByDate[dateKey]!['expense'] += amount;
      } else {
        trendByDate[dateKey]!['income'] += amount;
      }
    }

    // Sort Trend
    final sortedDateKeys = trendByDate.keys.toList()
      ..sort(
        (a, b) => (trendByDate[a]!['sortKey'] as int).compareTo(
          trendByDate[b]!['sortKey'] as int,
        ),
      );

    final trendLabels = sortedDateKeys;
    final trendIncomeValues = sortedDateKeys
        .map((k) => trendByDate[k]!['income'])
        .toList();
    final trendExpenseValues = sortedDateKeys
        .map((k) => trendByDate[k]!['expense'])
        .toList();

    double burnRatePercentage = totalBudget > 0
        ? (totalExpense / totalBudget) * 100
        : 0;

    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'burnRate': {
        'totalBudget': totalBudget,
        'totalExpense': totalExpense,
        'percentage': burnRatePercentage,
      },
      'expenseByCategory': expenseByCategory.values.toList(),
      'trend': {
        'labels': trendLabels,
        'datasets': [
          {
            'name': 'Chi tiêu',
            'color': '#FF5722',
            'values': trendExpenseValues,
          },
          {'name': 'Thu nhập', 'color': '#4CAF50', 'values': trendIncomeValues},
        ],
      },
      'aiInsight': 'Tính năng AI Insight không khả dụng khi ngoại tuyến.',
    };
  }
}
