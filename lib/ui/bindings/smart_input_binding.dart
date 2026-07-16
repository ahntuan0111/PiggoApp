import 'package:get/get.dart';
import 'package:appintern/ui/controllers/smart_input_controller.dart';

class SmartInputBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SmartInputController>(() => SmartInputController());
  }
}
