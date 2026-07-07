import 'dart:async';

import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'dart:math' as math;
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/core/network/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/domain/repositories/wallet_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';

class BudgetCategoryGroup {
  final String typeId;
  final String typeName;
  final List<BudgetCategory> categories;

  BudgetCategoryGroup(this.typeId, this.typeName, this.categories);
}

class HomeController extends BaseController {
  final storage = Get.find<StorageService>();
  final CategoryRepository categoryRepository = Get.find<CategoryRepository>();
  final WalletRepository walletRepository = Get.find<WalletRepository>();

  var userName = "Đang tải...".obs;
  var currentUserId = "".obs;

  // Lắng nghe Stream
  StreamSubscription? _txSubscription;

  // Thay thế tĩnh bằng Biến số Rx để UI tự cập nhật khi dữ liệu đổi
  final currentMonth = 'Tháng 7 2026'.obs;

  final totalWalletBalance = 0.0.obs;
  final allocatedAmount = 0.0.obs;
  final unallocatedAmount = 0.0.obs;

  final categories = <BudgetCategory>[].obs;
  final categoryGroups = <BudgetCategoryGroup>[].obs;

  @override
  void onInit() {
    super.onInit();
    userName.value = storage.read(AppKeys.userName) ?? "Đang tải...";
    currentUserId.value = storage.read(AppKeys.userId) ?? "";

    // Lắng nghe sự kiện thêm Giao dịch từ Repository (Reactive Programming - Chuẩn Rule 2C)
    final txRepo = Get.find<TransactionRepository>();
    _txSubscription = txRepo.onTransactionUpdated.listen((_) {
      fetchData(); // Tự động gọi lại fetchData() khi có thông báo
    });
  }

  @override
  void onReady() {
    super.onReady();
    fetchData();
  }

  Future<void> fetchData() async {
    final userId = currentUserId.value;
    if (userId.isEmpty) return;

    showLoading();
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
                        icon: c.iconName,
                        name: c.name,
                        allocated: c.defaultBudget,
                        spent: c.spent, // Lấy đúng giá trị từ Database
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

      // Lấy danh sách ví và tính tổng số dư
      final wallets = await walletRepository.getWallets(userId);
      totalWalletBalance.value = wallets.fold(0.0, (sum, w) => sum + w.balance);

      // Tính toán tiền đã phân bổ (còn lại) và chưa phân bổ (Zero-based budgeting)
      // Tổng số tiền CÒN LẠI trong các quỹ (những khoản tiền đã cất đi nhưng chưa xài tới)
      double totalRemainingBudgets = categories.fold(
        0.0,
        (sum, c) => sum + math.max(0, c.allocated - c.spent),
      );

      allocatedAmount.value = totalRemainingBudgets;
      
      // Tiền chưa phân bổ = Số dư thực tế trong ví - Tổng số dư chưa xài trong quỹ
      unallocatedAmount.value = totalWalletBalance.value - totalRemainingBudgets;
    }, tag: "FETCH_HOME_DATA");
    hideLoading();

    result.fold((failure) {
      print("Error fetching home categories: ${failure.message}");

      showErrorMessage(
        "Lỗi",
        "Không thể tải dữ liệu trang chủ: ${failure.message}",
      );
    }, (_) {});
  }

  // Hàm tiện ích format tiền tệ (thay cho thư viện intl để giữ app nhẹ)
  String formatCurrency(double amount) {
    String numStr = amount.toStringAsFixed(0);
    return numStr.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        ) +
        'đ';
  }

  @override
  void onClose() {
    _txSubscription?.cancel();
    super.onClose();
  }
}
