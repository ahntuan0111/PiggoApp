import 'package:get/get.dart';
import 'package:appintern/ui/controllers/budget_distribution_controller.dart';

class BudgetDistributionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BudgetDistributionController>(
      () => BudgetDistributionController(),
    );
  }
}
