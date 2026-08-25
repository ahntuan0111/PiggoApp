import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/services/settings_service.dart';
import 'package:get/get.dart';

class BudgetSettingsController extends BaseController {
  final SettingsService _settingsService = Get.find<SettingsService>();

  RxString get currencyCode => _settingsService.currencyCode;
  String get currencySymbol => _settingsService.currencySymbol;
  RxString get numberFormat => _settingsService.numberFormat;
  RxString get symbolPosition => _settingsService.symbolPosition;

  void saveSettings(String code, String format, String position) {
    _settingsService.save(code, format, position);
  }
}
