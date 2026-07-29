import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:get/get.dart';
import 'package:appintern/data/models/transaction_model.dart';

class LocalDatabaseService extends GetxService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'appintern_scale.db');
    return await openDatabase(path, version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,);
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Table Transactions (Dành cho Lịch sử Giao dịch)
    await db.execute('''
      CREATE TABLE transactions(
        id TEXT PRIMARY KEY,
        categoryId TEXT,
        amount REAL,
        type TEXT,
        transactionDate TEXT,
        status TEXT,
        note TEXT
      )
    ''');
    // Đánh Index để Query siêu tốc theo tháng
    await db.execute(
      'CREATE INDEX idx_transaction_date ON transactions(transactionDate)',
    );
    await db.execute(
      'CREATE INDEX idx_transaction_category ON transactions(categoryId)',
    );

    // 2. Table Offline Tasks Queue (Dành cho Sync ngầm)
    await db.execute('''
      CREATE TABLE offline_tasks_queue(
        id TEXT PRIMARY KEY,
        task_type TEXT,
        payload TEXT,
        status TEXT,
        created_at TEXT,
        retry_count INTEGER,
        next_retry_time TEXT,
        parsed_data TEXT
        
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_queue_status ON offline_tasks_queue(status)',
    );

    // 3. Table App Cache (Dành cho Categories, Budget, Wallet Balance)
    await db.execute('''
      CREATE TABLE app_cache(
        key TEXT PRIMARY KEY,
        json_data TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE offline_tasks_queue ADD COLUMN parsed_data TEXT');
    }
  }

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
  // TRANSACTIONS (SCALE-READY)
  // ==========================================
  Future<void> saveTransactions(List<TransactionModel> txs) async {
    final db = await database;
    Batch batch = db.batch();
    for (var tx in txs) {
      batch.insert('transactions', {
        'id': tx.id,
        'categoryId': tx.categoryId,
        'amount': tx.amount,
        'type': tx.type,
        'transactionDate': tx.transactionDate.toIso8601String(),
        'status': tx.status,
        'note': tx.note ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<TransactionModel>> getTransactionsByMonth(
    String monthYearStr,
  ) async {
    final db = await database;
    // monthYearStr có định dạng MM-YYYY
    final parts = monthYearStr.split('-');
    if (parts.length != 2) return [];

    final year = parts[1];
    final month = parts[0].padLeft(2, '0');
    final startPrefix = '$year-$month-'; // Ví dụ: 2026-07-

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'transactionDate LIKE ?',
      whereArgs: ['$startPrefix%'],
      orderBy: 'transactionDate DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel(
        id: maps[i]['id'] as String,
        categoryId: maps[i]['categoryId'] as String,
        amount: maps[i]['amount'] as double,
        type: maps[i]['type'] as String,
        transactionDate: DateTime.parse(maps[i]['transactionDate'] as String),
        status: maps[i]['status'] as String,
        note: maps[i]['note'] as String?,
      );
    });
  }

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
  
  Future<void> updateOfflineTaskParsedData(String id, String parsedData, String newStatus) async {
    final db = await database;
    await db.update(
      'offline_tasks_queue',
      {
        'parsed_data': parsedData,
        'status': newStatus,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('offline_tasks_queue', where: 'id = ?', whereArgs: [id]);
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
