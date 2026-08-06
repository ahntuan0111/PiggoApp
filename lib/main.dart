import 'package:appintern/data/repositories/auth_repository.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/statistics_repository.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
import 'package:appintern/data/repositories/transfer_log_repository.dart';
import 'package:appintern/data/repositories/rollover_repository.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/routes/app_pages.dart';
import 'core/services/appwrite_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/network_service.dart';
import 'domain/services/i_ai_service.dart';
import 'package:appintern/data/data_sources/remote/appwrite_ai_service_impl.dart';

import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'core/services/offline_sync_service.dart';
import 'core/services/sync_engine_service.dart';
import 'core/services/background_worker.dart';
import 'package:appintern/core/theme/app_theme.dart';
import 'package:workmanager/workmanager.dart';

import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Khởi tạo WorkManager
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode, // Tự động false khi build Production
  );

  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => NotificationService().init());
  await Get.putAsync(() => SettingsService().init());
  await Get.putAsync(() => AppwriteService().init());

  // Services (Nên khởi tạo Data Sources trước)
  Get.put(LocalDatabaseService());
  Get.put(NetworkService());

  final appwriteService = Get.find<AppwriteService>();
  Get.put(AuthRepository(appwriteService));
  Get.put(CategoryRepository(appwriteService));
  Get.put(StorageRepository(appwriteService));
  Get.put(TransactionRepository(appwriteService));
  Get.put(GoalRepository(appwriteService));
  Get.put(TransferLogRepository(appwriteService));
  Get.put(RolloverRepository(appwriteService));
  Get.put(StatisticsRepository(appwriteService));
  Get.put(AppwriteAIServiceImpl());
  Get.put<IAIService>(Get.find<AppwriteAIServiceImpl>());

  // BudgetService phụ thuộc vào Repositories nên phải khởi tạo sau
  Get.put(BudgetService());

  // Offline Sync
  Get.put(OfflineSyncService());
  Get.put(SyncEngineService());

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
        return GetMaterialApp(
          title: 'Personal Finance App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _getThemeMode(),
          initialRoute: AppPages.INITIAL,
          getPages: AppPages.pages,
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
      return ThemeMode.system;
    } catch (e) {
      return ThemeMode.system;
    }
  }
}
