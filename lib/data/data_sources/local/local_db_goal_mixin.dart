import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';

mixin LocalDbGoalMixin on LocalDatabaseBase {
  // ==========================================
  // GOALS
  // ==========================================
  Future<void> saveGoals(List<Map<String, dynamic>> goals) async {
    final db = await database;
    Batch batch = db.batch();
    
    // Purge logic: Xóa các records đã sync (bảo toàn offline ghosts nếu có)
    batch.delete('goals', where: "id NOT LIKE 'offline_%'");
    
    for (var g in goals) {
      batch.insert('goals', {
        'id': g['id'],
        'categoryId': g['categoryId'],
        'name': g['name'],
        'targetAmount': g['targetAmount'],
        'currentAmount': g['currentAmount'],
        'deadline': g['deadline'],
        'status': g['status'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getGoals() async {
    final db = await database;
    return await db.query('goals');
  }

  Future<void> updateLocalGoalAmount(
    String categoryId,
    double amountChange,
  ) async {
    final db = await database;
    final existing = await db.query(
      'goals',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
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
}
