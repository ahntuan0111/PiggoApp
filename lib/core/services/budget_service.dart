import 'dart:async';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:get/get.dart';
import 'package:appintern/core/utils/logger.dart';
import 'package:appintern/data/models/budget_category_group.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/models/monthly_budget_model.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'dart:convert';

class BudgetService extends GetxService {
  final StorageService storage = Get.find<StorageService>();
  final CategoryRepository categoryRepository = Get.find<CategoryRepository>();
  final TransactionRepository transactionRepository =
      Get.find<TransactionRepository>();
  final GoalRepository goalRepository = Get.find<GoalRepository>();

  var currentUserId = "".obs;
  var currentTrackingMonth = DateTime.now().obs;

  final totalWalletBalance = 0.0.obs;
  final allocatedAmount = 0.0.obs;
  final unallocatedAmount = 0.0.obs;

  final categories =
      <BudgetCategory>[].obs; // Chứa TẤT CẢ danh mục (cả active và bị ẩn)
  final categoryGroups = <BudgetCategoryGroup>[].obs; // Chứa TẤT CẢ các nhóm

  // Danh sách chỉ chứa các danh mục đang hoạt động (isActive = true)
  List<BudgetCategory> get activeCategories =>
      categories.where((c) => c.categoryModel.isActive).toList();

  List<BudgetCategoryGroup> get activeCategoryGroups {
    return categoryGroups
        .map((group) {
          return BudgetCategoryGroup(
            group.typeId,
            group.typeName,
            group.categories.where((c) => c.categoryModel.isActive).toList(),
          );
        })
        .where((g) => g.categories.isNotEmpty)
        .toList();
  }

  final goals = <GoalModel>[].obs;
  final monthlyBudgets = <MonthlyBudgetModel>[].obs;

  var isDataLoaded = false.obs;
  var isError = false.obs;
  var errorMessage = "".obs;

  StreamSubscription? _txSubscription;

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = storage.read(AppKeys.userId) ?? "";

    // Listen to transaction updates
    _txSubscription = transactionRepository.onTransactionUpdated.listen((_) {
      refreshData();
    });
  }

  Future<void> refreshData() async {
    // Luôn đọc lại userId phòng trường hợp vừa login xong
    currentUserId.value = storage.read(AppKeys.userId) ?? "";
    final userId = currentUserId.value;

    if (userId.isEmpty) {
      isError.value = true;
      errorMessage.value = "Người dùng chưa đăng nhập";
      // Đánh dấu loaded để tránh kẹt loading ở HomeController
      isDataLoaded.value = true;
      return;
    }

    final localDb = Get.find<LocalDatabaseService>();
    bool hasLoadedFromCache = false;

    // 1. THỬ LOAD TỪ CACHE TRƯỚC TIÊN (ZERO LOADING)
    try {
      final cachedData = await localDb.getAppCache('budget_data_\$userId');
      if (cachedData != null) {
        _parseAndSetBudgetData(
          typesData: List<Map<String, dynamic>>.from(cachedData['types']),
          catsData: List<Map<String, dynamic>>.from(cachedData['cats']),
          budgetsData: List<Map<String, dynamic>>.from(cachedData['budgets']),
          goalsData: List<Map<String, dynamic>>.from(cachedData['goals']),
          summariesData: List<Map<String, dynamic>>.from(
            cachedData['summaries'],
          ),
        );
        isDataLoaded.value = true;
        hasLoadedFromCache = true;
      }
    } catch (e) {
      AppLogger.error("CACHE_READ_ERROR", e.toString());
    }

    // 2. FETCH TỪ APPWRITE (BACKGROUND SYNC)
    final result = await ErrorHandler.execute(() async {
      final types = await categoryRepository.getCategoryTypes(userId);
      List<BudgetCategoryGroup> tempGroups = [];
      List<BudgetCategory> tempCategories = [];
      List<CategoryModel> cats = [];
      List<MonthlyBudgetModel> fetchedMonthlyBudgets = [];

      if (types.isNotEmpty) {
        final typeIds = types.map((e) => e.id).toList();
        cats = await categoryRepository.getCategories(typeIds);

        String monthYearStr =
            "${currentTrackingMonth.value.month.toString().padLeft(2, '0')}-${currentTrackingMonth.value.year}";
        fetchedMonthlyBudgets = await categoryRepository.getMonthlyBudgets(
          monthYearStr,
        );
        monthlyBudgets.value = fetchedMonthlyBudgets;

        for (var type in types) {
          final typeCats = cats
              .where((c) => c.categoryTypeId == type.id)
              .toList();
          if (typeCats.isNotEmpty) {
            tempGroups.add(
              BudgetCategoryGroup(
                type.id,
                type.name,
                typeCats.map((c) {
                  final mb = fetchedMonthlyBudgets.firstWhereOrNull(
                    (m) => m.categoryId == c.id,
                  );
                  return BudgetCategory(
                    categoryModel: c,
                    icon: c.iconName,
                    name: c.name,
                    allocated:
                        (mb?.budgetedAmount ?? 0.0) +
                        (mb?.rolloverAmount ?? 0.0),
                    spent: mb?.spentAmount ?? 0.0,
                  );
                }).toList(),
              ),
            );
          }
        }
        tempCategories = tempGroups.expand((g) => g.categories).toList();
      }

      final fetchedGoals = await goalRepository.getGoals();

      // Lấy tất cả MonthlySummaries của user để tính dòng tiền
      final allSummaries = await categoryRepository.getAllMonthlySummaries();

      // GHI CACHE RAW DATA ĐỂ LẦN SAU ĐỌC
      await localDb.saveAppCache('budget_data_\$userId', {
        'types': types.map((e) => e.toMap()).toList(),
        'cats': cats.map((e) => e.toMap()).toList(),
        'budgets': fetchedMonthlyBudgets.map((e) => e.toMap()).toList(),
        'goals': fetchedGoals.map((e) => e.toMap()).toList(),
        'summaries': allSummaries.map((e) => e.toMap()).toList(),
      });

      _parseAndSetBudgetData(
        typesData: types.map((e) => e.toMap()).toList(),
        catsData: cats.map((e) => e.toMap()).toList(),
        budgetsData: fetchedMonthlyBudgets.map((e) => e.toMap()).toList(),
        goalsData: fetchedGoals.map((e) => e.toMap()).toList(),
        summariesData: allSummaries.map((e) => e.toMap()).toList(),
      );
    }, tag: "FETCH_BUDGET_DATA");

    result.fold(
      (failure) {
        AppLogger.error("FETCH_BUDGET_DATA", failure.message);
        if (!hasLoadedFromCache) {
          isError.value = true;
          errorMessage.value = failure.message;
        }
      },
      (_) {
        isError.value = false;
        errorMessage.value = "";
        isDataLoaded.value = true;
      },
    );
  }

  void _parseAndSetBudgetData({
    required List<Map<String, dynamic>> typesData,
    required List<Map<String, dynamic>> catsData,
    required List<Map<String, dynamic>> budgetsData,
    required List<Map<String, dynamic>> goalsData,
    required List<Map<String, dynamic>> summariesData,
  }) {
    List<BudgetCategoryGroup> tempGroups = [];
    List<BudgetCategory> tempCategories = [];

    if (typesData.isNotEmpty) {
      final fetchedMonthlyBudgets = budgetsData
          .map((e) => MonthlyBudgetModel.fromMap(e))
          .toList();
      monthlyBudgets.value = fetchedMonthlyBudgets;

      final cats = catsData.map((e) => CategoryModel.fromMap(e)).toList();

      for (var typeMap in typesData) {
        final typeId = typeMap['id'] ?? '';
        final typeName = typeMap['name'] ?? '';

        final typeCats = cats.where((c) => c.categoryTypeId == typeId).toList();
        if (typeCats.isNotEmpty) {
          tempGroups.add(
            BudgetCategoryGroup(
              typeId,
              typeName,
              typeCats.map((c) {
                final mb = fetchedMonthlyBudgets.firstWhereOrNull(
                  (m) => m.categoryId == c.id,
                );
                return BudgetCategory(
                  categoryModel: c,
                  icon: c.iconName,
                  name: c.name,
                  allocated:
                      (mb?.budgetedAmount ?? 0.0) + (mb?.rolloverAmount ?? 0.0),
                  spent: mb?.spentAmount ?? 0.0,
                );
              }).toList(),
            ),
          );
        }
      }
      tempCategories = tempGroups.expand((g) => g.categories).toList();
    }

    categoryGroups.value = tempGroups;
    categories.value = tempCategories;

    final validCategoryIds = tempCategories
        .map((c) => c.categoryModel.id)
        .toSet();
    final fetchedGoals = goalsData.map((e) => GoalModel.fromMap(e)).toList();

    // Filter goals exactly as previously done in GoalController
    final userGoals = fetchedGoals
        .where(
          (g) =>
              validCategoryIds.contains(g.categoryId) &&
              g.name.trim().isNotEmpty &&
              g.targetAmount > 0,
        )
        .toList();
    goals.value = userGoals;

    // Tính tổng Thu, tổng Chi của tất cả các tháng
    double totalAllTimeIncome = summariesData.fold(
      0.0,
      (sum, s) => sum + (s['totalIncome'] ?? 0.0),
    );
    double totalAllTimeExpense = summariesData.fold(
      0.0,
      (sum, s) => sum + (s['totalExpense'] ?? 0.0),
    );

    // Tổng ngân sách hiện tại = Tổng Thu - Tổng Chi
    totalWalletBalance.value = totalAllTimeIncome - totalAllTimeExpense;

    double totalRemainingBudgets = tempCategories.fold(
      0.0,
      (sum, c) => sum + (c.allocated - c.spent),
    );

    allocatedAmount.value = totalRemainingBudgets;

    // Số tiền chưa phân bổ = Tổng ngân sách - Tổng đã phân bổ (còn lại)
    unallocatedAmount.value = totalWalletBalance.value - totalRemainingBudgets;
  }

  MonthlyBudgetModel? getBudgetForCategory(String categoryId) {
    return monthlyBudgets.firstWhereOrNull((m) => m.categoryId == categoryId);
  }

  @override
  void onClose() {
    _txSubscription?.cancel();
    super.onClose();
  }
}
