import 'package:get/get.dart';
import 'package:appintern/ui/features/rollover/controllers/overspent_compensation_controller.dart';

class OverspentCompensationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => OverspentCompensationController());
  }
}
