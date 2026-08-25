import 'package:appintern/ui/features/home/controllers/main_controller.dart';
import 'package:appintern/ui/features/home/controllers/home_controller.dart';
import 'package:appintern/ui/features/profile/controllers/profile_controller.dart';
import 'package:appintern/ui/features/wallet/controllers/wallet_controller.dart';
import 'package:appintern/ui/features/smart/controllers/smart_input_controller.dart';
import 'package:appintern/ui/features/statistics/controllers/statistics_controller.dart';
import 'package:get/get.dart';

class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(MainController(), permanent: true);
    Get.lazyPut<HomeController>(() => HomeController(), fenix: true);
    Get.lazyPut<ProfileController>(() => ProfileController(), fenix: true);
    Get.lazyPut<WalletController>(() => WalletController(), fenix: true);
    Get.lazyPut<SmartInputController>(
      () => SmartInputController(),
      fenix: true,
    );

    Get.lazyPut<StatisticsController>(
      () => StatisticsController(),
      fenix: true,
    );
  }
}
