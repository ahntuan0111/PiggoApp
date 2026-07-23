import 'package:get/get.dart';
import 'package:appintern/ui/controllers/rollover_controller.dart';

class RolloverBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RolloverController>(() => RolloverController());
  }
}
