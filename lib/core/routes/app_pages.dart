import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/ui/features/budget/bindings/budget_distribution_binding.dart';
import 'package:appintern/ui/features/budget/bindings/category_binding.dart';
import 'package:appintern/ui/features/budget/bindings/category_detail_binding.dart';
import 'package:appintern/ui/features/goal/bindings/goal_binding.dart';
import 'package:appintern/ui/features/goal/bindings/goal_create_binding.dart';
import 'package:appintern/ui/features/goal/bindings/goal_detail_binding.dart';
import 'package:appintern/ui/features/wallet/bindings/wallet_create_binding.dart';
import 'package:appintern/ui/features/home/bindings/main_binding.dart';
import 'package:appintern/ui/features/auth/bindings/onboarding_binding.dart';
import 'package:appintern/ui/features/rollover/bindings/overspent_compensation_binding.dart';
import 'package:appintern/ui/features/rollover/bindings/overspent_list_binding.dart';
import 'package:appintern/ui/features/smart/bindings/smart_input_binding.dart';
import 'package:appintern/ui/features/transaction/bindings/transaction_create_binding.dart';
import 'package:appintern/ui/features/transaction/bindings/transaction_detail_binding.dart';
import 'package:appintern/ui/features/transaction/bindings/transaction_history_binding.dart';
import 'package:appintern/ui/features/smart/bindings/voice_input_binding.dart';
import 'package:appintern/ui/features/rollover/bindings/month_end_report_binding.dart';
import 'package:appintern/ui/features/rollover/bindings/rollover_decision_binding.dart';
import 'package:appintern/ui/features/rollover/bindings/new_month_setup_binding.dart';
import 'package:appintern/ui/features/rollover/bindings/multi_month_gap_binding.dart';
import 'package:appintern/ui/features/budget/screens/budget_distribution_screen.dart';
import 'package:appintern/ui/features/budget/screens/category_detail_screen.dart';
import 'package:appintern/ui/features/budget/screens/category_screen.dart';
import 'package:appintern/ui/features/goal/screens/goal_create_screen.dart';
import 'package:appintern/ui/features/goal/screens/goal_detail_screen.dart';
import 'package:appintern/ui/features/goal/screens/goal_screen.dart';
import 'package:appintern/ui/features/home/screens/main_screen.dart';
import 'package:appintern/ui/features/auth/screens/onboarding_screen.dart';
import 'package:appintern/ui/features/rollover/screens/overspent_compensation_screen.dart';
import 'package:appintern/ui/features/rollover/screens/overspent_list_screen.dart';
import 'package:appintern/ui/features/smart/screens/smart_input_screen.dart';
import 'package:appintern/ui/features/transaction/screens/transaction_create_screen.dart';
import 'package:appintern/ui/features/transaction/screens/transaction_detail_screen.dart';
import 'package:appintern/ui/features/transaction/screens/transaction_history_screen.dart';
import 'package:appintern/ui/features/smart/screens/voice_input_screen.dart';
import 'package:appintern/ui/features/wallet/screens/wallet_create_screen.dart';
import 'package:appintern/ui/features/rollover/screens/month_end_report_screen.dart';
import 'package:appintern/ui/features/rollover/screens/rollover_decision_screen.dart';
import 'package:appintern/ui/features/rollover/screens/new_month_setup_screen.dart';
import 'package:appintern/ui/features/rollover/screens/multi_month_gap_screen.dart';
import 'package:appintern/ui/features/sync/screens/offline_queue_screen.dart';
import 'package:appintern/ui/features/sync/bindings/offline_queue_binding.dart';
import 'package:appintern/ui/features/auth/bindings/splash_binding.dart';
import 'package:appintern/ui/features/statistics/screens/statistics_screen.dart';
import 'package:appintern/ui/features/statistics/bindings/statistics_binding.dart';
import 'package:appintern/ui/features/budget/screens/budget_settings_screen.dart';
import 'package:appintern/ui/features/budget/bindings/budget_settings_binding.dart';
import 'package:appintern/ui/features/auth/screens/splash_screen.dart';
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
