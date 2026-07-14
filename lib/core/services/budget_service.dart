import 'dart:async';
import 'package:get/get.dart';
import 'dart:math' as math;
import 'package:appintern/data/models/budget_category_group.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/data/models/wallet_model.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/domain/repositories/wallet_repository.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';

class BudgetService extends GetxService {
  final StorageService storage = Get.find<StorageService>();
  final CategoryRepository categoryRepository = Get.find<CategoryRepository>();
  final WalletRepository walletRepository = Get.find<WalletRepository>();
  final TransactionRepository txRepo = Get.find<TransactionRepository>();

  var currentUserId = "".obs;

  final totalWalletBalance = 0.0.obs;
  final allocatedAmount = 0.0.obs;
  final unallocatedAmount = 0.0.obs;

  final categories = <BudgetCategory>[].obs;
  final categoryGroups = <BudgetCategoryGroup>[].obs;
  final wallets = <WalletModel>[].obs;

  var isDataLoaded = false.obs;
  var isError = false.obs;
  var errorMessage = "".obs;

  StreamSubscription? _txSubscription;

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = storage.read(AppKeys.userId) ?? "";

    // Listen to transaction updates
    _txSubscription = txRepo.onTransactionUpdated.listen((_) {
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

    final result = await ErrorHandler.execute(() async {
      final types = await categoryRepository.getCategoryTypes(userId);
      if (types.isNotEmpty) {
        final typeIds = types.map((e) => e.id).toList();
        final cats = await categoryRepository.getCategories(typeIds);

        final List<BudgetCategoryGroup> groups = [];
        for (var type in types) {
          final typeCats = cats
              .where((c) => c.categoryTypeId == type.id)
              .toList();
          if (typeCats.isNotEmpty) {
            groups.add(
              BudgetCategoryGroup(
                type.id,
                type.name,
                typeCats
                    .map(
                      (c) => BudgetCategory(
                        categoryModel: c,
                        icon: c.iconName,
                        name: c.name,
                        allocated: c.defaultBudget,
                        spent: c.spent,
                      ),
                    )
                    .toList(),
              ),
            );
          }
        }
        categoryGroups.value = groups;
        categories.value = groups.expand((g) => g.categories).toList();
      } else {
        categories.clear();
        categoryGroups.clear();
      }

      final fetchedWallets = await walletRepository.getWallets(userId);
      wallets.value = fetchedWallets;
      totalWalletBalance.value = fetchedWallets.fold(0.0, (sum, w) => sum + w.balance);

      double totalRemainingBudgets = categories.fold(
        0.0,
        (sum, c) => sum + math.max(0, c.allocated - c.spent),
      );

      allocatedAmount.value = totalRemainingBudgets;
      unallocatedAmount.value =
          totalWalletBalance.value - totalRemainingBudgets;
    }, tag: "FETCH_BUDGET_DATA");

    result.fold(
      (failure) {
        print("Error fetching budget data: ${failure.message}");
        isError.value = true;
        errorMessage.value = failure.message;
      },
      (_) {
        isError.value = false;
        errorMessage.value = "";
        isDataLoaded.value = true;
      },
    );
  }

  @override
  void onClose() {
    _txSubscription?.cancel();
    super.onClose();
  }
}
