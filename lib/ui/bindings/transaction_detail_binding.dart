import 'package:appintern/ui/controllers/transaction_detail_controller.dart';
import 'package:get/get.dart';

class TransactionDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TransactionDetailController>(
      () => TransactionDetailController(),
    );
  }
}
