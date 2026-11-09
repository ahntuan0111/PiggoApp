import 'package:appintern/data/models/transfer_log_model.dart';
import 'package:get/get.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:sqflite/sqflite.dart';

class TransferLogRepository {
  final LocalDatabaseService _localDb;

  TransferLogRepository() : _localDb = Get.find<LocalDatabaseService>();

  Future<void> createTransferLog(TransferLogModel log, [String? userId]) async {
    final uid = userId ?? log.userId ?? _localDb.currentUserId;
    final db = await _localDb.database;
    final map = Map<String, dynamic>.from(log.toMap());
    map['userId'] = uid;
    if (map['id'] == null || (map['id'] as String).isEmpty) {
      map['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    }
    if (map['createdAt'] == null || (map['createdAt'] as String).isEmpty) {
      map['createdAt'] = DateTime.now().toIso8601String();
    }
    await db.insert(
      'transfer_logs',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TransferLogModel>> getTransferLogsByCategoryId(
    String categoryId, {
    int limit = 5,
    String? userId,
  }) async {
    final rawData = await _localDb.getTransferLogsByCategoryId(
      categoryId,
      limit: limit,
      userId: userId,
    );
    return rawData
        .map((data) => TransferLogModel.fromMap(data, docId: data['id']))
        .toList();
  }
}
