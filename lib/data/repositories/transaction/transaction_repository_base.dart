import 'dart:async';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:get/get.dart';

abstract class TransactionRepositoryBase {
  final AppwriteService appwrite;
  final LocalDatabaseService localDb = Get.find<LocalDatabaseService>();

  /// Broadcast stream để thông báo cho các controller khi transaction thay đổi.
  /// Lưu ý: Controller này sống suốt vòng đời app (Get.put trong main.dart),
  /// nên StreamController không cần close. Nếu thay đổi lifecycle,
  /// PHẢI gọi dispose() để close stream.
  final StreamController<void> transactionUpdatedController =
      StreamController<void>.broadcast();

  TransactionRepositoryBase(this.appwrite);

  void dispose() {
    transactionUpdatedController.close();
  }
}
