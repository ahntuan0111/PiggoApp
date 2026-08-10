import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/data/models/transfer_log_model.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';
import 'package:get/get.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';

class TransferLogRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;

  TransferLogRepository(this._appwrite);

  Future<void> createTransferLog(TransferLogModel log) async {
    return handleAppwriteError(() async {
      await _appwrite.databases.createDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.transferLogsTableId,
        documentId: ID.unique(),
        data: log.toMap(),
      );
    });
  }

  Future<List<TransferLogModel>> getTransferLogsByCategoryId(
    String categoryId, {
    int limit = 5,
  }) async {
    final network = Get.find<NetworkService>();
    final localDb = Get.find<LocalDatabaseService>();

    if (network.isOffline.value) {
      final rawData = await localDb.getTransferLogsByCategoryId(
        categoryId,
        limit: limit,
      );
      return rawData
          .map((data) => TransferLogModel.fromMap(data, docId: data['id']))
          .toList();
    }

    return handleAppwriteError(() async {
      final response = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.transferLogsTableId,
        queries: [
          Query.or([
            Query.equal('fromCategoryId', categoryId),
            Query.equal('toCategoryId', categoryId),
          ]),
          Query.orderDesc('\$createdAt'),
          Query.limit(limit),
        ],
      );

      return response.documents
          .map((doc) => TransferLogModel.fromMap(doc.data, docId: doc.$id))
          .toList();
    });
  }
}
