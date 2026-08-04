import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';

mixin LocalDbOfflineQueueMixin on LocalDatabaseBase {
  // ==========================================
  // OFFLINE QUEUE
  // ==========================================
  Future<void> addOfflineTask({
    required String id,
    required String taskType,
    required String payload,
    String? parsedData,
  }) async {
    final db = await database;
    await db.insert('offline_tasks_queue', {
      'id': id,
      'task_type': taskType,
      'payload': payload,
      'parsed_data': parsedData,
      'status': 'PENDING',
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
      'next_retry_time': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingTasks() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.query(
      'offline_tasks_queue',
      where: 'status = ? AND next_retry_time <= ?',
      whereArgs: ['PENDING', now],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> updateTaskStatus(
    String id,
    String status, {
    int? retryCount,
    String? nextRetryTime,
  }) async {
    final db = await database;
    Map<String, dynamic> values = {'status': status};
    if (retryCount != null) values['retry_count'] = retryCount;
    if (nextRetryTime != null) values['next_retry_time'] = nextRetryTime;

    await db.update(
      'offline_tasks_queue',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateOfflineTaskParsedData(
    String id,
    String parsedData,
    String newStatus,
  ) async {
    final db = await database;
    await db.update(
      'offline_tasks_queue',
      {'parsed_data': parsedData, 'status': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('offline_tasks_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceTempIdInTasks(String tempId, String realId) async {
    final db = await database;
    await db.execute(
      "UPDATE offline_tasks_queue SET payload = REPLACE(payload, ?, ?)",
      [tempId, realId],
    );
  }

  Future<int> getPendingQueueCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM offline_tasks_queue WHERE status = 'PENDING'",
      ),
    );
    return count ?? 0;
  }
}
