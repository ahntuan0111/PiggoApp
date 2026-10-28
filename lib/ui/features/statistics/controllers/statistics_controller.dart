import 'dart:async';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/data/repositories/statistics_repository.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:get/get.dart';

import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/data/models/transaction_model.dart';

class StatisticsController extends BaseController {
  final StatisticsRepository _statisticRepository =
      Get.find<StatisticsRepository>();
  final TransactionRepository _transactionRepository =
      Get.find<TransactionRepository>();
  final NetworkService _networkService = Get.find<NetworkService>();

  StreamSubscription? _transactionSub;

  final isInitialLoading = true.obs;
  final hasAnyDataOverall = true.obs;

  final barChartTimeframe = 'this_month'.obs;
  final donutChartTimeframe = 'this_month'.obs;
  final trendChartTimeframe = 'this_month'.obs;


  final aiInsight = ''.obs;

  final barChartData = <String, dynamic>{}.obs;
  final donutChartData = <String, dynamic>{}.obs;
  final trendChartData = <String, dynamic>{}.obs;

  final categoryAnalysisData = <String, dynamic>{}.obs;
  final categoryAnalysisTimeframe = '3_months'.obs;
  final selectedAnalysisCategoryId = ''.obs;
  final selectedAnalysisCategoryName = ''.obs;
  final selectedAnalysisCategoryIcon = ''.obs;

  bool get isOffline => _networkService.isOffline.value;

  @override
  void onInit() {
    super.onInit();
    _transactionSub = _transactionRepository.onTransactionUpdated.listen((_) {
      refreshData();
    });
    refreshData();
  }

  @override
  void onClose() {
    _transactionSub?.cancel();
    super.onClose();
  }

  Future<void> refreshData() async {
    if (isInitialLoading.value == false) {
      // If we are just refreshing data implicitly, don't show skeleton
      // But if we want a pull-to-refresh spinner, we can rely on RefreshIndicator
    } else {
      isInitialLoading.value = true;
    }

    await Future.wait([
      _fetchOfflineForBarChart(),
      _fetchOfflineForDonutChart(),
      _fetchOfflineForTrendChart(),
    ]);

    hasAnyDataOverall.value = await _statisticRepository.hasAnyTransactions();

    isInitialLoading.value = false;
    _autoSelectHighestCategory();
    _syncOnlineData();
  }

  // --- Bar Chart ---
  Future<void> fetchBarChartData(String timeframe) async {
    barChartTimeframe.value = timeframe;
    await _fetchOfflineForBarChart();
  }

  Future<void> _fetchOfflineForBarChart() async {
    final data = await _statisticRepository.getOfflineStatistics(
      barChartTimeframe.value,
    );
    barChartData.value = data['trend'] ?? {};
  }

  // --- Donut Chart ---
  Future<void> fetchDonutChartData(String timeframe) async {
    donutChartTimeframe.value = timeframe;
    await _fetchOfflineForDonutChart();
    _autoSelectHighestCategory();
  }

  Future<void> _fetchOfflineForDonutChart() async {
    final data = await _statisticRepository.getOfflineStatistics(
      donutChartTimeframe.value,
    );
    donutChartData.value = {
      'expenseByCategory': data['expenseByCategory'] ?? [],
      'totalExpense': data['totalExpense'] ?? 0,
    };
  }

  // --- Trend Area Chart ---
  Future<void> fetchTrendChartData(String timeframe) async {
    trendChartTimeframe.value = timeframe;
    await _fetchOfflineForTrendChart();
  }

  Future<void> _fetchOfflineForTrendChart() async {
    final data = await _statisticRepository.getOfflineStatistics(
      trendChartTimeframe.value,
    );
    trendChartData.value = data['trend'] ?? {};
  }


  // --- Online AI Insight Sync ---
  Future<void> _syncOnlineData() async {
    if (isOffline) return;

    final result = await ErrorHandler.execute(() async {
      return await _statisticRepository.getOfflineStatistics('this_month');
    });

    result.fold((l) => null, (data) {
      if (data.containsKey('aiInsight') || data.containsKey('insight')) {
        aiInsight.value = data['aiInsight'] ?? data['insight'] ?? '';
      }
    });
  }

  void _autoSelectHighestCategory() {
    final expenseByCategory = List<dynamic>.from(
      donutChartData['expenseByCategory'] ?? [],
    );
    if (expenseByCategory.isNotEmpty) {
      expenseByCategory.sort(
        (a, b) => (b['amount'] as num).compareTo(a['amount'] as num),
      );
      final topCat = expenseByCategory.first;
      final cid = topCat['id'] ?? topCat['name'];

      if (selectedAnalysisCategoryId.value.isEmpty ||
          !expenseByCategory.any(
            (c) => (c['id'] ?? c['name']) == selectedAnalysisCategoryId.value,
          )) {
        final name = topCat['name'];
        String icon = topCat['icon'] ?? 'assets/icons/others.png';
        if (!icon.startsWith('assets/')) {
          icon = 'assets/icons/$icon';
        }
        selectCategoryForAnalysis(cid, name, icon);
      } else {
        fetchCategoryAnalysis(selectedAnalysisCategoryId.value);
      }
    } else {
      selectedAnalysisCategoryId.value = '';
    }
  }

  void selectCategoryForAnalysis(
    String categoryId,
    String categoryName,
    String iconPath,
  ) {
    if (selectedAnalysisCategoryId.value == categoryId &&
        categoryAnalysisData.isNotEmpty)
      return;

    selectedAnalysisCategoryId.value = categoryId;
    selectedAnalysisCategoryName.value = categoryName;
    selectedAnalysisCategoryIcon.value = iconPath;

    fetchCategoryAnalysis(categoryId);
  }

  void changeCategoryAnalysisTimeframe(String timeframe) {
    categoryAnalysisTimeframe.value = timeframe;
    if (selectedAnalysisCategoryId.value.isNotEmpty) {
      fetchCategoryAnalysis(selectedAnalysisCategoryId.value);
    }
  }

  // --- Phân tích danh mục (Sử dụng TransactionRepository cho Offline/Online Sync) ---
  Future<void> fetchCategoryAnalysis(String categoryId) async {
    showLoading();

    final result = await ErrorHandler.execute(() async {
      final now = DateTime.now();
      DateTime startDate = DateTime(now.year, now.month, 1);
      final timeframe = categoryAnalysisTimeframe.value;

      if (timeframe == 'last_7_days') {
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 7));
      } else if (timeframe == 'this_month') {
        startDate = DateTime(now.year, now.month, 1);
      } else if (timeframe == '3_months') {
        startDate = DateTime(now.year, now.month - 2, 1);
      } else if (timeframe == '6_months') {
        startDate = DateTime(now.year, now.month - 5, 1);
      }

      final endDate = DateTime.now(); // Current time

      return await _transactionRepository.getHistoryByCategory(
        categoryId,
        start: startDate,
        end: endDate,
        limit: 1000,
      );
    }, tag: 'CATEGORY_ANALYSIS');

    result.fold(
      (failure) {
        // Fallback data if error
        categoryAnalysisData.value = {};
      },
      (historyList) {
        final timeframe = categoryAnalysisTimeframe.value;
        final now = DateTime.now();
        List<String> labels = [];
        Map<String, double> bucketValues = {};

        bool isMonthly = timeframe == '3_months' || timeframe == '6_months';

        if (isMonthly) {
          int monthsCount = timeframe == '3_months' ? 3 : 6;
          for (int i = monthsCount - 1; i >= 0; i--) {
            final d = DateTime(now.year, now.month - i, 1);
            final key = 'T${d.month}';
            labels.add(key);
            bucketValues[key] = 0.0;
          }
        } else {
          // Daily breakdown for 7 days or this month
          int daysCount = timeframe == 'last_7_days' ? 7 : now.day;
          for (int i = daysCount - 1; i >= 0; i--) {
            final d = now.subtract(Duration(days: i));
            final key = '${d.day}/${d.month}';
            labels.add(key);
            bucketValues[key] = 0.0;
          }
        }

        for (var item in historyList) {
          final TransactionModel tx = item['transaction'];
          if (tx.type == 'EXPENSE') {
            String key;
            if (isMonthly) {
              key = 'T${tx.transactionDate.month}';
            } else {
              key = '${tx.transactionDate.day}/${tx.transactionDate.month}';
            }
            if (bucketValues.containsKey(key)) {
              bucketValues[key] = (bucketValues[key] ?? 0) + tx.amount;
            }
          }
        }

        final values = labels.map((l) => bucketValues[l] ?? 0.0).toList();
        final total = values.fold(0.0, (sum, val) => sum + val);
        final average = labels.isNotEmpty ? total / labels.length : 0.0;

        // If all values are 0, it means no transactions
        if (total == 0) {
          categoryAnalysisData.value = {};
        } else {
          categoryAnalysisData.value = {
            'labels': labels,
            'values': values,
            'average': average,
          };
        }
      },
    );

    hideLoading();
  }
}
