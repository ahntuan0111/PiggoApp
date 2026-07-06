import 'package:get/get.dart';
import 'package:appintern/core/network/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'app_routes.dart';
import '../../ui/screens/onboarding_screen.dart';
import '../../ui/screens/main_screen.dart';
import '../../ui/screens/category_screen.dart';
import '../../ui/bindings/onboarding_binding.dart';
import '../../ui/bindings/main_binding.dart';
import '../../ui/bindings/category_binding.dart';

class AppPages {
  static String get INITIAL {
    final storage = Get.find<StorageService>();
    bool isLoggedIn = storage.read<bool>(AppKeys.isLoggedIn) ?? false;
    return isLoggedIn ? Routes.MAIN : Routes.ONBOARDING;
  }

  static final pages = [
    GetPage(
      name: Routes.ONBOARDING,
      page: () => const OnboardingScreen(),
      binding: OnboardingBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.MAIN,
      page: () => MainScreen(),
      binding: MainBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.CATEGORY,
      page: () => const CategoryScreen(),
      binding: CategoryBinding(),
      transition: Transition.rightToLeft,
    ),
  ];
}
