import 'package:appintern/ui/controllers/main_controller.dart';
import 'package:appintern/ui/controllers/home_controller.dart';
import 'package:get/get.dart';

class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(MainController(), permanent: true);
    Get.lazyPut<HomeController>(() => HomeController(), fenix: true);
  }
}
