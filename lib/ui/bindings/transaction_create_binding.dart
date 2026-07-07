import 'package:get/get.dart';
import 'package:appintern/ui/controllers/transaction_create_controller.dart';

class TransactionCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TransactionCreateController>(
      () => TransactionCreateController(),
    );
  }
}
