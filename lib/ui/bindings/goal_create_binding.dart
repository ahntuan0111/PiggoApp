import 'package:appintern/ui/controllers/goal_create_controller.dart';
import 'package:get/get.dart';

class GoalCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => GoalCreateController());
  }
}
