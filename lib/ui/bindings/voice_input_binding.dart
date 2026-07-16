import 'package:get/get.dart';
import 'package:appintern/ui/controllers/voice_input_controller.dart';

class VoiceInputBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => VoiceInputController());
  }
}
