import 'package:get/get.dart';
import 'package:appintern/ui/features/rollover/controllers/multi_month_gap_controller.dart';

class MultiMonthGapBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MultiMonthGapController>(() => MultiMonthGapController());
  }
}
