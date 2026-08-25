import 'package:get/get.dart';
import 'package:appintern/ui/features/smart/controllers/voice_input_controller.dart';

class VoiceInputBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => VoiceInputController());
  }
}
