import 'package:get/get.dart';
import 'package:appintern/ui/features/budget/controllers/budget_settings_controller.dart';

class BudgetSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => BudgetSettingsController());
  }
}
