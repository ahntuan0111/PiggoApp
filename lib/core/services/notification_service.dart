import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:appintern/core/routes/app_routes.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Callback này chạy trong isolate riêng.
  // Thường thì FlutterLocalNotifications tự trigger lại onDidReceiveNotificationResponse ở main isolate.
}

class NotificationService extends GetxService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int dailyReminderId = 1001;

  Future<NotificationService> init() async {
    await _configureLocalTimeZone();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
            final payload = notificationResponse.payload;
            if (payload == 'daily_reminder') {
              // Cố gắng điều hướng đến trang tạo giao dịch.
              Future.delayed(const Duration(milliseconds: 300), () {
                if (Get.currentRoute != Routes.TRANSACTION_CREATE) {
                  Get.toNamed(Routes.TRANSACTION_CREATE);
                }
              });
            }
          },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    return this;
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final currentTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));
    } catch (e) {
      debugPrint('Lỗi khởi tạo TimeZone: $e');
    }
  }

  Future<bool> requestPermissions() async {
    bool granted = false;

    // Android 13+ permissions
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      granted =
          (await androidImplementation.requestNotificationsPermission()) ??
          false;
      await androidImplementation.requestExactAlarmsPermission();
    } else {
      // iOS
      final iosImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImplementation != null) {
        granted =
            (await iosImplementation.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            )) ??
            false;
      }
    }

    return granted;
  }

  Future<void> scheduleDailyReminder(int hour, int minute) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: dailyReminderId,
      title: 'Nhắc nhở ghi chép',
      body: 'Đến lúc tổng kết thu chi của ngày hôm nay rồi bạn nhé!',
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Nhắc nhở hàng ngày',
          channelDescription: 'Nhắc nhở nhập giao dịch hằng ngày',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_reminder',
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancel(id: dailyReminderId);
  }
}
