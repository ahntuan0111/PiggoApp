import 'dart:async';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:get/get.dart';

abstract class TransactionRepositoryBase {
  final AppwriteService appwrite;
  final LocalDatabaseService localDb = Get.find<LocalDatabaseService>();
  final StreamController<void> transactionUpdatedController =
      StreamController<void>.broadcast();

  TransactionRepositoryBase(this.appwrite);

  void dispose() {
    transactionUpdatedController.close();
  }
}
