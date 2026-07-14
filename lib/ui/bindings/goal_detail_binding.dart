import 'package:get/get.dart';
import 'package:appintern/ui/controllers/goal_detail_controller.dart';

class GoalDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GoalDetailController>(() => GoalDetailController());
  }
}
