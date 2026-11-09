import 'package:appintern/data/repositories/auth_repository.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/statistics_repository.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
import 'package:appintern/data/repositories/transfer_log_repository.dart';
import 'package:appintern/data/repositories/rollover_repository.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/core/services/data_retention_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/routes/app_pages.dart';
import 'core/services/storage_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/network_service.dart';
import 'domain/services/i_ai_service.dart';
import 'package:appintern/data/data_sources/local/local_ai_service_impl.dart';

import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/core/theme/app_theme.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
      "⚠️ Không tìm thấy file .env, sử dụng cấu hình mặc định ngoại tuyến.",
    );
  }

  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => NotificationService().init());
  await Get.putAsync(() => SettingsService().init());

  // Services (Nên khởi tạo Data Sources trước)
  Get.put(LocalDatabaseService());
  Get.put(NetworkService());

  Get.put(AuthRepository());
  Get.put(CategoryRepository());
  Get.put(TransactionRepository());

  Get.lazyPut(() => StorageRepository(), fenix: true);
  Get.lazyPut(() => GoalRepository(), fenix: true);
  Get.lazyPut(() => TransferLogRepository(), fenix: true);
  Get.lazyPut(() => RolloverRepository(), fenix: true);
  Get.lazyPut(() => StatisticsRepository(), fenix: true);
  Get.lazyPut(() => DataRetentionService(), fenix: true);
  Get.lazyPut(() => LocalAIServiceImpl(), fenix: true);
  Get.lazyPut<IAIService>(() => Get.find<LocalAIServiceImpl>(), fenix: true);

  // BudgetService phụ thuộc vào Repositories nên phải khởi tạo sau
  Get.put(BudgetService());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 800),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Obx(
          () => GetMaterialApp(
            title: 'Personal Finance App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _getThemeMode(),
            initialRoute: AppPages.INITIAL,
            getPages: AppPages.pages,
          ),
        );
      },
    );
  }

  ThemeMode _getThemeMode() {
    try {
      final settings = Get.find<SettingsService>();
      final mode = settings.themeMode.value;
      if (mode == 'light') return ThemeMode.light;
      if (mode == 'dark') return ThemeMode.dark;
      return ThemeMode.light;
    } catch (e) {
      return ThemeMode.light;
    }
  }
}
