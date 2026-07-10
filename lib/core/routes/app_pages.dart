import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/ui/bindings/wallet_create_binding.dart';
import 'package:appintern/ui/screens/wallet_create_screen.dart';
import 'package:appintern/ui/bindings/budget_distribution_binding.dart';
import 'package:appintern/ui/screens/transaction_create_screen.dart';
import 'package:appintern/ui/bindings/transaction_create_binding.dart';
import 'package:appintern/ui/screens/budget_distribution_screen.dart';
import 'package:get/get.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'app_routes.dart';
import '../../ui/screens/onboarding_screen.dart';
import '../../ui/screens/main_screen.dart';
import '../../ui/screens/category_screen.dart';
import '../../ui/bindings/onboarding_binding.dart';
import '../../ui/bindings/main_binding.dart';
import '../../ui/bindings/category_binding.dart';
import '../../ui/screens/category_detail_screen.dart';
import '../../ui/bindings/category_detail_binding.dart';

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
    GetPage(
      name: Routes.WALLETCREATE,
      page: () => const WalletCreateScreen(),
      binding: WalletCreateBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.BUDGET_DISTRIBUTION,
      page: () => const BudgetDistributionScreen(),
      binding: BudgetDistributionBinding(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.TRANSACTION_CREATE,
      page: () => const TransactionCreateScreen(),
      binding: TransactionCreateBinding(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.CATEGORY_DETAIL,
      page: () => const CategoryDetailScreen(),
      binding: CategoryDetailBinding(),
      transition: Transition.rightToLeft,
    ),
  ];
}
