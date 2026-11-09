import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:get/get.dart';

class StatisticsRepository {
  StatisticsRepository();

  Future<bool> hasAnyTransactions() async {
    final localDb = Get.find<LocalDatabaseService>();
    return await localDb.hasAnyTransactions();
  }

  Future<Map<String, dynamic>> getOfflineStatistics(String timeframe) async {
    final localDb = Get.find<LocalDatabaseService>();
    final now = DateTime.now();

    // 1. Xác định mốc thời gian
    DateTime startDate = DateTime(now.year, now.month, now.day);
    int monthsCount = 0;
    if (timeframe == 'last_7_days') {
      startDate = startDate.subtract(const Duration(days: 7));
    } else if (timeframe == 'this_month') {
      startDate = DateTime(now.year, now.month, 1);
    } else if (timeframe == '3_months') {
      startDate = DateTime(now.year, now.month - 2, 1);
      monthsCount = 3;
    } else if (timeframe == '6_months') {
      startDate = DateTime(now.year, now.month - 5, 1);
      monthsCount = 6;
    }

    // 2. Lấy dữ liệu giao dịch hiện có trên máy
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
    final Set<String> monthsWithActiveTxs = {};

    // 4.1. Gom nhóm từ giao dịch chi tiết còn lưu trên máy
    for (var tx in transactions) {
      final amount = tx.amount;
      final isExpense = tx.type == 'EXPENSE';

      final txMonthStr =
          "${tx.transactionDate.month.toString().padLeft(2, '0')}-${tx.transactionDate.year}";
      monthsWithActiveTxs.add(txMonthStr);

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

    // 4.2. HỢP NHẤT DỮ LIỆU ĐÃ NÉN / PRUNED CHO CÁC THÁNG CŨ (NẾU CÓ)
    if (isMonthlyTrend && monthsCount > 0) {
      final List<String> allRangeMonthYears = [];
      for (int i = monthsCount - 1; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        final mStr = "${d.month.toString().padLeft(2, '0')}-${d.year}";
        allRangeMonthYears.add(mStr);

        final monthKey = 'Tháng ${d.month}';
        if (!trendByDate.containsKey(monthKey)) {
          trendByDate[monthKey] = {
            'income': 0.0,
            'expense': 0.0,
            'sortKey': d.millisecondsSinceEpoch,
          };
        }
      }

      // Các tháng trong khoảng thời gian mà không còn transaction chi tiết (đã bị prune)
      final missingMonths = allRangeMonthYears
          .where((m) => !monthsWithActiveTxs.contains(m))
          .toList();

      if (missingMonths.isNotEmpty) {
        // A. Nạp tổng thu/chi từ monthly_summaries
        final summaries = await localDb.getMonthlySummaries();
        for (final ms in summaries) {
          final mYear = ms['monthYear'] as String? ?? '';
          if (missingMonths.contains(mYear)) {
            final parts = mYear.split('-');
            final mNum = int.tryParse(parts[0]) ?? 1;
            final mKey = 'Tháng $mNum';

            final inc = (ms['totalIncome'] as num?)?.toDouble() ?? 0.0;
            final exp = (ms['totalExpense'] as num?)?.toDouble() ?? 0.0;

            totalIncome += inc;
            totalExpense += exp;

            if (trendByDate.containsKey(mKey)) {
              trendByDate[mKey]!['income'] =
                  (trendByDate[mKey]!['income'] as double) + inc;
              trendByDate[mKey]!['expense'] =
                  (trendByDate[mKey]!['expense'] as double) + exp;
            }
          }
        }

        // B. Nạp phân loại danh mục từ monthly_category_summaries
        final catSummaries =
            await localDb.getMonthlyCategorySummariesForRange(missingMonths);
        for (final cs in catSummaries) {
          final cid = cs['categoryId'] as String? ?? 'uncategorized';
          final exp = (cs['totalExpense'] as num?)?.toDouble() ?? 0.0;

          if (exp > 0) {
            if (!expenseByCategory.containsKey(cid)) {
              expenseByCategory[cid] = {
                'id': cid,
                'amount': 0.0,
                'name': cs['categoryName'] ?? categoriesMap[cid]?['name'] ?? 'Khác',
                'color': cs['categoryColor'] ?? categoriesMap[cid]?['color'] ?? '#9E9E9E',
                'icon': cs['categoryIcon'] ??
                    categoriesMap[cid]?['iconName'] ??
                    'assets/icons/others.png',
              };
            }
            expenseByCategory[cid]!['amount'] += exp;
          }
        }
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

  /// Lấy xu hướng chi tiêu theo danh mục qua các tháng (hỗ trợ cả dữ liệu đã nén/archive)
  Future<Map<String, double>> getCategoryMonthlyTrend(
    String categoryId,
    int monthsCount,
  ) async {
    final localDb = Get.find<LocalDatabaseService>();
    final now = DateTime.now();
    final Map<String, double> result = {};

    final List<DateTime> months = [];
    final List<String> monthYearList = [];
    for (int i = monthsCount - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      months.add(d);
      monthYearList.add('${d.month.toString().padLeft(2, '0')}-${d.year}');
      result['T${d.month}'] = 0.0;
    }

    // 1. Lấy từ transactions còn lưu trong máy
    final startDate = months.first;
    final txs = await localDb.getTransactionsByDateRange(startDate, now);
    final Set<String> activeMonthsWithTxs = {};

    for (final tx in txs) {
      final mStr =
          '${tx.transactionDate.month.toString().padLeft(2, '0')}-${tx.transactionDate.year}';
      activeMonthsWithTxs.add(mStr);
      if (tx.categoryId == categoryId && tx.type == 'EXPENSE') {
        final key = 'T${tx.transactionDate.month}';
        result[key] = (result[key] ?? 0.0) + tx.amount;
      }
    }

    // 2. Với các tháng cũ đã bị prune (không có trong activeMonthsWithTxs), lấy từ monthly_category_summaries
    final missingMonths =
        monthYearList.where((m) => !activeMonthsWithTxs.contains(m)).toList();
    if (missingMonths.isNotEmpty) {
      final summaries = await localDb.getMonthlyCategorySummariesByCategoryId(
        categoryId,
        missingMonths,
      );
      for (final s in summaries) {
        final mYear = s['monthYear'] as String? ?? '';
        final parts = mYear.split('-');
        if (parts.isNotEmpty) {
          final mNum = int.tryParse(parts[0]);
          if (mNum != null) {
            final key = 'T$mNum';
            final exp = (s['totalExpense'] as num?)?.toDouble() ?? 0.0;
            result[key] = exp;
          }
        }
      }
    }

    return result;
  }
}
