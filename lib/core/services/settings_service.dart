import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/services/notification_service.dart';

class SettingsService extends GetxService {
  final _storage = Get.find<StorageService>();

  final currencyCode = 'VND'.obs;
  final numberFormat = 'dot'.obs; // 'dot' | 'comma' | 'space' | 'none'
  final symbolPosition = 'after'.obs; // 'before' | 'after' | 'hidden'
  final themeMode = 'light'.obs; // 'light' | 'dark'

  // Notification Settings
  final isDailyReminderEnabled = false.obs;
  final reminderTime = '20:00'.obs;

  String get currencySymbol =>
      _currencyMap[currencyCode.value]?['symbol'] ?? 'đ';
  String get currencyName =>
      _currencyMap[currencyCode.value]?['name'] ?? 'Vietnamese Dong';
  String get currencyFlag =>
      _currencyMap[currencyCode.value]?['flag'] ?? 'vnd.png';

  static const _currencyMap = {
    'VND': {'symbol': 'đ', 'name': 'Vietnamese Dong', 'flag': 'vnd.png'},
    'USD': {'symbol': '\$', 'name': 'US Dollar', 'flag': 'usd.png'},
    'SGD': {'symbol': 'S\$', 'name': 'Singapore Dollar', 'flag': 'sgd.png'},
    'EUR': {'symbol': '€', 'name': 'Euro', 'flag': 'eur.png'},
    'GBP': {'symbol': '£', 'name': 'British Pound', 'flag': 'gbp.png'},
    'AUD': {'symbol': 'A\$', 'name': 'Australian Dollar', 'flag': 'aud.png'},
    'CAD': {'symbol': 'C\$', 'name': 'Canadian Dollar', 'flag': 'cad.png'},
    'CNY': {'symbol': '¥', 'name': 'Chinese Yuan', 'flag': 'cny.png'},
    // 'JPY': {'symbol': '¥', 'name': 'Japanese Yen', 'flag': 'jpy.png'},
    // 'KRW': {'symbol': '₩', 'name': 'South Korean Won', 'flag': 'krw.png'},
  };

  Future<SettingsService> init() async {
    _loadFromLocal();
    return this;
  }

  void _loadFromLocal() {
    currencyCode.value = _storage.read<String>(AppKeys.currencyCode) ?? 'VND';
    numberFormat.value = _storage.read<String>(AppKeys.numberFormat) ?? 'dot';
    symbolPosition.value =
        _storage.read<String>(AppKeys.symbolPosition) ?? 'after';
    themeMode.value = _storage.read<String>('themeMode') ?? 'light';
    isDailyReminderEnabled.value =
        _storage.read<bool>('isDailyReminderEnabled') ?? false;
    reminderTime.value = _storage.read<String>('reminderTime') ?? '20:00';
  }

  Future<void> loadFromCloud() async {
    // Migration Phase C: In offline/local mode, settings are loaded from GetStorage.
  }

  void save(String newCurrency, String newFormat, String newPosition) {
    currencyCode.value = newCurrency;
    numberFormat.value = newFormat;
    symbolPosition.value = newPosition;

    _saveToLocal();
  }

  void saveTheme(String newTheme) {
    themeMode.value = newTheme;
    _storage.write('themeMode', newTheme);

    if (newTheme == 'light')
      Get.changeThemeMode(ThemeMode.light);
    else if (newTheme == 'dark')
      Get.changeThemeMode(ThemeMode.dark);
    else
      Get.changeThemeMode(ThemeMode.system);
  }

  void saveNotificationSettings(bool isEnabled, String time) {
    isDailyReminderEnabled.value = isEnabled;
    reminderTime.value = time;

    _storage.write('isDailyReminderEnabled', isEnabled);
    _storage.write('reminderTime', time);

    _applyNotificationSettings();
  }

  void _applyNotificationSettings() {
    try {
      final notifService = Get.find<NotificationService>();
      if (isDailyReminderEnabled.value) {
        final parts = reminderTime.value.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]) ?? 20;
          final min = int.tryParse(parts[1]) ?? 0;
          notifService.scheduleDailyReminder(hour, min);
        }
      } else {
        notifService.cancelAll();
      }
    } catch (e) {
      debugPrint("Failed to apply notification settings: $e");
    }
  }

  void _saveToLocal() {
    _storage.write(AppKeys.currencyCode, currencyCode.value);
    _storage.write(AppKeys.numberFormat, numberFormat.value);
    _storage.write(AppKeys.symbolPosition, symbolPosition.value);
  }

  void _syncToCloud() {
    // Migration Phase C: Local-first persistence only. No cloud sync required.
  }
}
