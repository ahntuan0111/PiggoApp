import 'package:appintern/domain/repositories/auth_repository.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:appintern/domain/repositories/storage_repository.dart';
import 'package:appintern/domain/repositories/goal_repository.dart';
import 'package:appintern/domain/repositories/transfer_log_repository.dart';
import 'package:appintern/domain/repositories/rollover_repository.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/routes/app_pages.dart';
import 'core/services/appwrite_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/network_service.dart';
import 'domain/services/i_ai_service.dart';
import 'core/services/appwrite_ai_service_impl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => AppwriteService().init());

  final appwriteService = Get.find<AppwriteService>();
  Get.put(AuthRepository(appwriteService));
  Get.put(CategoryRepository(appwriteService));
  Get.put(StorageRepository(appwriteService));
  Get.put(TransactionRepository(appwriteService));
  Get.put(GoalRepository(appwriteService));
  Get.put(TransferLogRepository(appwriteService));
  Get.put(RolloverRepository(appwriteService));

  // Services
  Get.put(NetworkService());
  Get.put(BudgetService());
  Get.put<IAIService>(AppwriteAIServiceImpl());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Khởi tạo ScreenUtil để Responsive UI theo kích thước bản vẽ Figma
    return ScreenUtilInit(
      designSize: const Size(360, 800), // Kích thước chuẩn trên Figma
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        // Đổi từ MaterialApp sang GetMaterialApp để dùng GetX Router
        return GetMaterialApp(
          title: 'Personal Finance App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFF9F7F1),
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          // CẤU HÌNH ROUTER BẰNG GETX THEO CHUẨN CLEAN ARCHITECTURE
          initialRoute: AppPages.INITIAL,
          getPages: AppPages.pages,
        );
      },
    );
  }
}
