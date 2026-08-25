import 'package:get/get.dart';
import 'package:appintern/ui/features/budget/controllers/category_controller.dart';

class CategoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CategoryController());
  }
}
