import 'dart:convert';
import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';

mixin LocalDbCacheMixin on LocalDatabaseBase {
  // ==========================================
  // CACHE: APP DATA (HOME, WALLET, CATEGORIES)
  // ==========================================
  Future<void> saveAppCache(String key, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('app_cache', {
      'key': key,
      'json_data': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getAppCache(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_cache',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return jsonDecode(maps.first['json_data'] as String);
    }
    return null;
  }

  // ==========================================
  // SYNC LOCK (Chống chạy trùng giữa UI & Background)
  // ==========================================
  static const String _syncLockKey = 'sync_lock';
  static const int _lockTimeoutSeconds = 120; // 2 phút

  /// Cố gắng chiếm quyền sync. Trả về true nếu thành công.
  Future<bool> acquireSyncLock() async {
    final db = await database;
    final existing = await db.query(
      'app_cache',
      where: 'key = ?',
      whereArgs: [_syncLockKey],
    );

    if (existing.isNotEmpty) {
      final lockData = jsonDecode(existing.first['json_data'] as String);
      final lockedAt = DateTime.tryParse(lockData['locked_at'] ?? '');
      if (lockedAt != null) {
        final elapsed = DateTime.now().difference(lockedAt).inSeconds;
        if (elapsed < _lockTimeoutSeconds) {
          return false; // Đang có luồng khác sync
        }
      }
    }

    // Chiếm lock
    await db.insert('app_cache', {
      'key': _syncLockKey,
      'json_data': jsonEncode({'locked_at': DateTime.now().toIso8601String()}),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  /// Giải phóng lock sau khi sync xong.
  Future<void> releaseSyncLock() async {
    final db = await database;
    await db.delete('app_cache', where: 'key = ?', whereArgs: [_syncLockKey]);
  }
}
