import 'package:appintern/ui/controllers/main_controller.dart';
import 'package:appintern/ui/controllers/home_controller.dart';
import 'package:appintern/ui/controllers/profile_controller.dart';
import 'package:appintern/ui/controllers/wallet_controller.dart';
import 'package:appintern/ui/controllers/smart_input_controller.dart';
import 'package:appintern/data/repositories/statistics_repository.dart';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/ui/controllers/statistics_controller.dart';
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

    Get.lazyPut<StatisticsRepository>(
      () => StatisticsRepository(Get.find<AppwriteService>()),
      fenix: true,
    );
    Get.lazyPut<StatisticsController>(
      () => StatisticsController(),
      fenix: true,
    );
  }
}
