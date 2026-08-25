import 'package:get/get.dart';
import 'package:appintern/ui/features/rollover/controllers/rollover_decision_controller.dart';

class RolloverDecisionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RolloverDecisionController>(() => RolloverDecisionController());
  }
}
