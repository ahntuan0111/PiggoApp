import 'package:get/get.dart';
import 'package:appintern/ui/controllers/rollover_decision_controller.dart';

class RolloverDecisionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RolloverDecisionController>(() => RolloverDecisionController());
  }
}
