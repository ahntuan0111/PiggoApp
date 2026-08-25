import 'package:get/get.dart';
import 'package:appintern/ui/features/sync/controllers/offline_queue_controller.dart';

class OfflineQueueBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => OfflineQueueController());
  }
}
