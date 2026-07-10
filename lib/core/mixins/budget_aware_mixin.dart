import 'package:get/get.dart';
import 'package:appintern/core/services/budget_service.dart';

/// Mixin dành cho các Controller cần tương tác với BudgetService.
/// Thay vì mỗi Controller đều phải Get.find<BudgetService>(),
/// chỉ cần thêm `with BudgetAware` để sử dụng chung.
mixin BudgetAware {
  final BudgetService budgetService = Get.find<BudgetService>();

  /// Tải lại toàn bộ dữ liệu ngân sách, danh mục, giao dịch từ DB
  void refreshBudget() => budgetService.refreshData();
}
