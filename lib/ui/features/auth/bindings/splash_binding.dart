import 'package:get/get.dart';
import 'package:appintern/ui/features/auth/controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<SplashController>(SplashController());
  }
}
