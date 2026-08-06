import 'dart:async';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/ui/widgets/dialogs/budget_warning_dialog.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/data/models/budget_category_group.dart';
import 'package:appintern/core/utils/currency_formatter.dart';

class HomeController extends BaseController with BudgetAware {
  final storage = Get.find<StorageService>();

  var userName = "Đang tải...".obs;

  RxDouble get totalWalletBalance => budgetService.totalWalletBalance;
  RxDouble get allocatedAmount => budgetService.allocatedAmount;
  RxDouble get unallocatedAmount => budgetService.unallocatedAmount;

  List<BudgetCategory> get categories => budgetService.activeCategories;
  List<BudgetCategoryGroup> get categoryGroups =>
      budgetService.activeCategoryGroups;

  int get overspentCategoriesCount {
    return categories.where((cat) => cat.remaining < 0).length;
  }

  final currentMonth =
      'Tháng ${DateTime.now().month} ${DateTime.now().year}'.obs;

  @override
  void onInit() {
    super.onInit();
    userName.value = storage.read(AppKeys.userName) ?? "Đang tải...";

    // Listen to BudgetService loading state to show/hide loading indicator
    ever(budgetService.isDataLoaded, (loaded) {
      if (loaded) hideLoading();
    });

    ever(budgetService.isError, (error) {
      if (error) {
        hideLoading();
        showErrorMessage(
          "Lỗi",
          "Không thể tải dữ liệu trang chủ: ${budgetService.errorMessage.value}",
        );
      }
    });
  }

  @override
  void onReady() {
    super.onReady();
    fetchData();
  }

  Future<void> fetchData() async {
    // Luôn gọi refreshData để đảm bảo dữ liệu mới nhất khi vừa login xong
    // hoặc khi chuyển từ màn hình Splash
    await budgetService.refreshData();
  }

  // Hàm tiện ích format tiền tệ (thay cho thư viện intl để giữ app nhẹ)
  String formatCurrency(double amount) {
    return CurrencyFormatter.format(amount);
  }

  void showWarningDialog() {
    Get.dialog(BudgetWarningDialog(unallocatedAmount: unallocatedAmount.value));
  }
}
