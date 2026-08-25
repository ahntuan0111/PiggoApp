import 'package:appintern/ui/features/wallet/controllers/wallet_controller.dart';
import 'package:get/get.dart';

class WalletCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => WalletController());
  }
}
