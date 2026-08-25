import 'package:get/get.dart';
import 'package:appintern/ui/features/rollover/controllers/new_month_setup_controller.dart';

class NewMonthSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NewMonthSetupController>(() => NewMonthSetupController());
  }
}
