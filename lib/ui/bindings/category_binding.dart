import 'package:get/get.dart';
import 'package:appintern/core/network/appwrite_service.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/ui/controllers/category_controller.dart';

class CategoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CategoryController());
  }
}
