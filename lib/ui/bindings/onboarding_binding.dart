import 'package:get/get.dart';
import 'package:appintern/ui/controllers/onboarding_controller.dart';

import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/core/services/appwrite_service.dart';

class OnboardingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CategoryRepository(Get.find<AppwriteService>()));
    Get.lazyPut(() => OnboardingController());
  }
}
