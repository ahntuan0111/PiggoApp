import 'package:get/get.dart';
import 'package:appintern/ui/features/rollover/controllers/overspent_list_controller.dart';

class OverspentListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => OverspentListController());
  }
}
