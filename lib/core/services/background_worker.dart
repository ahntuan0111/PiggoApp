import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/services/sync_engine_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/data/data_sources/remote/appwrite_ai_service_impl.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/repositories/transfer_log_repository.dart';
import 'package:appintern/domain/services/i_ai_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: ".env");

      // 1. Storage & Appwrite
      await Get.putAsync(() => StorageService().init());
      await Get.putAsync(() => AppwriteService().init());
      final appwriteService = Get.find<AppwriteService>();

      // 2. Kiểm tra phiên đăng nhập (Session)
      // Background Isolate không có UI, nên nếu chưa đăng nhập thì không thể sync.
      try {
        await appwriteService.account.get();
      } catch (_) {
        debugPrint("Background Sync: Chưa đăng nhập, bỏ qua.");
        return Future.value(false); // WorkManager sẽ retry sau
      }

      // 3. Services (không phụ thuộc Repositories)
      Get.put(LocalDatabaseService());
      Get.put(NetworkService());
      Get.put(AppwriteAIServiceImpl());
      Get.put<IAIService>(Get.find<AppwriteAIServiceImpl>());

      // 4. Repositories
      Get.put(StorageRepository(appwriteService));
      Get.put(CategoryRepository(appwriteService));
      Get.put(TransactionRepository(appwriteService));
      Get.put(GoalRepository(appwriteService));
      Get.put(TransferLogRepository(appwriteService));

      // 5. BudgetService (cần Repositories)
      Get.put(BudgetService());
      final budgetService = Get.find<BudgetService>();
      await budgetService.refreshData();

      // 5. Sync Engine
      Get.put(SyncEngineService());
      final syncEngine = Get.find<SyncEngineService>();

      // Chạy Sync
      await syncEngine.startForegroundSync();

      return Future.value(true);
    } catch (e) {
      debugPrint("Background Task Failed: $e");
      return Future.value(
        false,
      ); // Nếu fail thì WorkManager sẽ retry theo chính sách của nó
    }
  });
}
