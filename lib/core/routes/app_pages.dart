import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/ui/bindings/budget_distribution_binding.dart';
import 'package:appintern/ui/bindings/category_binding.dart';
import 'package:appintern/ui/bindings/category_detail_binding.dart';
import 'package:appintern/ui/bindings/goal_binding.dart';
import 'package:appintern/ui/bindings/goal_create_binding.dart';
import 'package:appintern/ui/bindings/goal_detail_binding.dart';
import 'package:appintern/ui/bindings/wallet_create_binding.dart';
import 'package:appintern/ui/bindings/main_binding.dart';
import 'package:appintern/ui/bindings/onboarding_binding.dart';
import 'package:appintern/ui/bindings/overspent_compensation_binding.dart';
import 'package:appintern/ui/bindings/overspent_list_binding.dart';
import 'package:appintern/ui/bindings/smart_input_binding.dart';
import 'package:appintern/ui/bindings/transaction_create_binding.dart';
import 'package:appintern/ui/bindings/transaction_detail_binding.dart';
import 'package:appintern/ui/bindings/transaction_history_binding.dart';
import 'package:appintern/ui/bindings/voice_input_binding.dart';
import 'package:appintern/ui/bindings/month_end_report_binding.dart';
import 'package:appintern/ui/bindings/rollover_decision_binding.dart';
import 'package:appintern/ui/bindings/new_month_setup_binding.dart';
import 'package:appintern/ui/bindings/multi_month_gap_binding.dart';
import 'package:appintern/ui/screens/budget_distribution_screen.dart';
import 'package:appintern/ui/screens/category_detail_screen.dart';
import 'package:appintern/ui/screens/category_screen.dart';
import 'package:appintern/ui/screens/goal_create_screen.dart';
import 'package:appintern/ui/screens/goal_detail_screen.dart';
import 'package:appintern/ui/screens/goal_screen.dart';
import 'package:appintern/ui/screens/main_screen.dart';
import 'package:appintern/ui/screens/onboarding_screen.dart';
import 'package:appintern/ui/screens/overspent_compensation_screen.dart';
import 'package:appintern/ui/screens/overspent_list_screen.dart';
import 'package:appintern/ui/screens/smart_input_screen.dart';
import 'package:appintern/ui/screens/transaction_create_screen.dart';
import 'package:appintern/ui/screens/transaction_detail_screen.dart';
import 'package:appintern/ui/screens/transaction_history_screen.dart';
import 'package:appintern/ui/screens/voice_input_screen.dart';
import 'package:appintern/ui/screens/wallet_create_screen.dart';
import 'package:appintern/ui/screens/month_end_report_screen.dart';
import 'package:appintern/ui/screens/rollover_decision_screen.dart';
import 'package:appintern/ui/screens/new_month_setup_screen.dart';
import 'package:appintern/ui/screens/multi_month_gap_screen.dart';
import 'package:appintern/ui/screens/offline_queue_screen.dart';
import 'package:appintern/ui/bindings/offline_queue_binding.dart';
import 'package:appintern/ui/bindings/splash_binding.dart';
import 'package:appintern/ui/screens/statistics_screen.dart';
import 'package:appintern/ui/bindings/statistics_binding.dart';
import 'package:appintern/ui/screens/budget_settings_screen.dart';
import 'package:appintern/ui/bindings/budget_settings_binding.dart';
import 'package:appintern/ui/screens/splash_screen.dart';
import 'package:get/get.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'app_routes.dart';

class AppPages {
  static String get INITIAL {
    final storage = Get.find<StorageService>();
    bool isLoggedIn = storage.read<bool>(AppKeys.isLoggedIn) ?? false;
    return isLoggedIn ? Routes.SPLASH : Routes.ONBOARDING;
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
    GetPage(
      name: Routes.OVERSPENT_COMPENSATION,
      page: () => const OverspentCompensationScreen(),
      binding: OverspentCompensationBinding(),
      transition: Transition.rightToLeft, // maybe downToUp?
    ),
    GetPage(
      name: Routes.OVERSPENT_LIST,
      page: () => const OverspentListScreen(),
      binding: OverspentListBinding(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.TRANSACTION_HISTORY,
      page: () => TransactionHistoryScreen(),
      binding: TransactionHistoryBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.GOAL,
      page: () => const GoalScreen(),
      binding: GoalBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.GOAL_CREATE,
      page: () => const GoalCreateScreen(),
      binding: GoalCreateBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.GOAL_DETAIL,
      page: () => const GoalDetailScreen(),
      binding: GoalDetailBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.SMART_INPUT,
      page: () => const SmartInputScreen(),
      binding: SmartInputBinding(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.VOICE_INPUT,
      page: () => const VoiceInputScreen(),
      binding: VoiceInputBinding(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.TRANSACTION_DETAIL,
      page: () => const TransactionDetailScreen(),
      binding: TransactionDetailBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.MONTH_END_REPORT,
      page: () => const MonthEndReportScreen(),
      binding: MonthEndReportBinding(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.ROLLOVER_DECISION,
      page: () => const RolloverDecisionScreen(),
      binding: RolloverDecisionBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.NEW_MONTH_SETUP,
      page: () => const NewMonthSetupScreen(),
      binding: NewMonthSetupBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.MULTI_MONTH_GAP,
      page: () => const MultiMonthGapScreen(),
      binding: MultiMonthGapBinding(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.OFFLINE_QUEUE,
      page: () => const OfflineQueueScreen(),
      binding: OfflineQueueBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.STATISTICS,
      page: () => const StatisticsScreen(),
      binding: StatisticsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.BUDGET_SETTINGS,
      page: () => const BudgetSettingsScreen(),
      binding: BudgetSettingsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.SPLASH,
      page: () => const SplashScreen(),
      binding: SplashBinding(),
      transition: Transition.fadeIn,
    ),
  ];
}
