import 'package:get/get.dart';
import 'package:appintern/ui/controllers/category_detail_controller.dart';

class CategoryDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CategoryDetailController());
  }
}
