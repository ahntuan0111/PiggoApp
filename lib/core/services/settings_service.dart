import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/core/services/notification_service.dart';

class SettingsService extends GetxService {
  final _storage = Get.find<StorageService>();

  final currencyCode = 'VND'.obs;
  final numberFormat = 'dot'.obs; // 'dot' | 'comma' | 'space' | 'none'
  final symbolPosition = 'after'.obs; // 'before' | 'after' | 'hidden'
  final themeMode = 'system'.obs; // 'system' | 'light' | 'dark'

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
    themeMode.value = _storage.read<String>('themeMode') ?? 'system';
    isDailyReminderEnabled.value = _storage.read<bool>('isDailyReminderEnabled') ?? false;
    reminderTime.value = _storage.read<String>('reminderTime') ?? '20:00';
  }

  Future<void> loadFromCloud() async {
    try {
      final appwrite = Get.find<AppwriteService>();
      final prefs = (await appwrite.account.getPrefs()).data;

      bool changed = false;
      if (prefs.containsKey('currencyCode')) {
        currencyCode.value = prefs['currencyCode'];
        changed = true;
      }
      if (prefs.containsKey('numberFormat')) {
        numberFormat.value = prefs['numberFormat'];
        changed = true;
      }
      if (prefs.containsKey('symbolPosition')) {
        symbolPosition.value = prefs['symbolPosition'];
        changed = true;
      }

      if (prefs.containsKey('themeMode')) {
        themeMode.value = prefs['themeMode'];
        changed = true;
      }

      if (changed) {
        _saveToLocal();
      }
    } catch (e) {
      print("Failed to load settings from cloud: $e");
    }
  }

  void save(String newCurrency, String newFormat, String newPosition) {
    currencyCode.value = newCurrency;
    numberFormat.value = newFormat;
    symbolPosition.value = newPosition;

    _saveToLocal();
    _syncToCloud();
  }

  void saveTheme(String newTheme) {
    themeMode.value = newTheme;
    _storage.write('themeMode', newTheme);
    _syncToCloud();

    if (newTheme == 'light') Get.changeThemeMode(ThemeMode.light);
    else if (newTheme == 'dark') Get.changeThemeMode(ThemeMode.dark);
    else Get.changeThemeMode(ThemeMode.system);
  }

  void saveNotificationSettings(bool isEnabled, String time) {
    isDailyReminderEnabled.value = isEnabled;
    reminderTime.value = time;
    
    _storage.write('isDailyReminderEnabled', isEnabled);
    _storage.write('reminderTime', time);
    
    _applyNotificationSettings();
    _syncToCloud();
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

  void _syncToCloud() async {
    try {
      final appwrite = Get.find<AppwriteService>();
      await appwrite.account.updatePrefs(
        prefs: {
          'currencyCode': currencyCode.value,
          'numberFormat': numberFormat.value,
          'symbolPosition': symbolPosition.value,
          'themeMode': themeMode.value,
          'isDailyReminderEnabled': isDailyReminderEnabled.value,
          'reminderTime': reminderTime.value,
        },
      );
    } catch (e) {
      print("Failed to sync settings to cloud: $e");
    }
  }
}
