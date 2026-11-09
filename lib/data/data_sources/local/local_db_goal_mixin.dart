import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';

mixin LocalDbGoalMixin on LocalDatabaseBase {
  // ==========================================
  // GOALS
  // ==========================================
  Future<void> saveGoals(
    List<Map<String, dynamic>> goals, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    Batch batch = db.batch();

    // Purge logic: Xóa các records đã sync của user này (bảo toàn offline ghosts nếu có)
    batch.delete(
      'goals',
      where: "userId = ? AND (id NOT LIKE 'offline_%' OR id IS NULL)",
      whereArgs: [effectiveUserId],
    );

    for (var g in goals) {
      batch.insert('goals', {
        'id': g['id'],
        'userId': g['userId'] ?? effectiveUserId,
        'categoryId': g['categoryId'] ?? g['categories'],
        'name': g['name'],
        'targetAmount': g['targetAmount'],
        'currentAmount': g['currentAmount'],
        'deadline': g['deadline'],
        'status': g['status'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getGoals({String? userId}) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    return await db.query(
      'goals',
      where: 'userId = ?',
      whereArgs: [effectiveUserId],
    );
  }

  Future<void> updateLocalGoalAmount(
    String categoryId,
    double amountChange, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    final existing = await db.query(
      'goals',
      where: 'categoryId = ? AND userId = ?',
      whereArgs: [categoryId, effectiveUserId],
    );
    if (existing.isNotEmpty) {
      double currentAmount = (existing.first['currentAmount'] as num)
          .toDouble();
      double newAmount = currentAmount + amountChange;
      if (newAmount < 0) newAmount = 0;
      await db.update(
        'goals',
        {'currentAmount': newAmount},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  Future<void> insertLocalGoal(
    Map<String, dynamic> goal, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    await db.insert('goals', {
      'id': goal['id'],
      'userId': goal['userId'] ?? effectiveUserId,
      'categoryId': goal['categoryId'] ?? goal['categories'],
      'name': goal['name'],
      'targetAmount': goal['targetAmount'],
      'currentAmount': goal['currentAmount'] ?? 0,
      'deadline': goal['deadline'],
      'status': goal['status'] ?? 'IN_PROGRESS',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateLocalGoal(
    Map<String, dynamic> goal, {
    String? userId,
  }) async {
    final db = await database;
    final whereClause = userId != null ? 'id = ? AND userId = ?' : 'id = ?';
    final whereArgs = userId != null ? [goal['id'], userId] : [goal['id']];
    await db.update(
      'goals',
      {
        'name': goal['name'],
        'targetAmount': goal['targetAmount'],
        'deadline': goal['deadline'],
        'status': goal['status'],
      },
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  Future<void> deleteLocalGoal(String id, {String? userId}) async {
    final db = await database;
    final whereClause = userId != null ? 'id = ? AND userId = ?' : 'id = ?';
    final whereArgs = userId != null ? [id, userId] : [id];
    await db.delete('goals', where: whereClause, whereArgs: whereArgs);
  }
}
