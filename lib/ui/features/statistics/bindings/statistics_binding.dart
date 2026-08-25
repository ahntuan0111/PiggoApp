import 'package:appintern/ui/features/statistics/controllers/statistics_controller.dart';
import 'package:get/get.dart';

class StatisticsBinding implements Bindings {
  @override
  void dependencies() {
    // Repository
    Get.lazyPut<StatisticsController>(() => StatisticsController());
  }
}
