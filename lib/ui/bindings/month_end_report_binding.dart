import 'package:get/get.dart';
import 'package:appintern/ui/controllers/month_end_report_controller.dart';

class MonthEndReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MonthEndReportController>(() => MonthEndReportController());
  }
}
