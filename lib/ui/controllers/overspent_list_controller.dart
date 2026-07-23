import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/core/routes/app_routes.dart';

class OverspentListController extends BaseController with BudgetAware {
  // Lấy danh sách các danh mục đang bị âm tiền
  List<BudgetCategory> get overspentCategories {
    return budgetService.categories.where((cat) => cat.remaining < 0).toList();
  }

  void navigateToCompensation(CategoryModel category) {
    Get.toNamed(Routes.OVERSPENT_COMPENSATION, arguments: category);
  }

  /// Pull-to-Refresh: reload dữ liệu các danh mục từ BudgetService
  Future<void> fetchData() async {
    await budgetService.refreshData();
  }
}

