import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'local_database_base.dart';
import 'local_db_transaction_mixin.dart';
import 'local_db_category_mixin.dart';
import 'local_db_budget_mixin.dart';
import 'local_db_goal_mixin.dart';
import '../../models/user_profile_model.dart';

class LocalDatabaseService extends LocalDatabaseBase
    with
        LocalDbTransactionMixin,
        LocalDbCategoryMixin,
        LocalDbBudgetMixin,
        LocalDbGoalMixin {
  static Database? _db;
  static Completer<Database>? _initCompleter;

  @override
  Future<Database> get database async {
    if (_db != null) return _db!;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<Database>();
    try {
      _db = await _initDB();
      _initCompleter!.complete(_db!);
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
    return _db!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'appintern_scale.db');
    return await openDatabase(
      path,
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Kích hoạt ràng buộc khóa ngoại
    await db.execute('PRAGMA foreign_keys = ON;');

    // 1. Table Category Types
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_types (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        priority INTEGER DEFAULT 99,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    // 2. Table Categories
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        categoryTypeId TEXT NOT NULL,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        iconName TEXT NOT NULL,
        defaultBudget REAL NOT NULL DEFAULT 0.0,
        targetAmount REAL,
        deadline TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT,
        FOREIGN KEY (categoryTypeId) REFERENCES category_types(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(categoryTypeId)',
    );

    // 3. Table Transactions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        categoryId TEXT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        transactionDate TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'COMPLETED',
        note TEXT DEFAULT '',
        createdAt TEXT,
        updatedAt TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transactionDate)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(categoryId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status)',
    );

    // 4. Table Transaction Details (1:1 với transactions)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transaction_details (
        id TEXT PRIMARY KEY,
        transactionId TEXT NOT NULL UNIQUE,
        note TEXT,
        receiptFileId TEXT,
        rawInputText TEXT,
        confidenceScore REAL,
        createdAt TEXT,
        updatedAt TEXT,
        FOREIGN KEY (transactionId) REFERENCES transactions(id) ON DELETE CASCADE
      )
    ''');

    // 5. Table Monthly Budgets
    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_budgets (
        id TEXT PRIMARY KEY,
        categoryId TEXT NOT NULL,
        monthYear TEXT NOT NULL,
        budgetedAmount REAL NOT NULL DEFAULT 0.0,
        rolloverAmount REAL NOT NULL DEFAULT 0.0,
        spentAmount REAL NOT NULL DEFAULT 0.0,
        createdAt TEXT,
        updatedAt TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_monthly_budgets_monthYear ON monthly_budgets(monthYear)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_mb_category_month ON monthly_budgets(categoryId, monthYear)',
    );

    // 6. Table Monthly Summaries
    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_summaries (
        id TEXT PRIMARY KEY,
        monthYear TEXT NOT NULL UNIQUE,
        totalIncome REAL NOT NULL DEFAULT 0.0,
        totalExpense REAL NOT NULL DEFAULT 0.0,
        unallocatedBalance REAL NOT NULL DEFAULT 0.0,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_monthly_summaries_monthYear ON monthly_summaries(monthYear)',
    );

    // 7. Table Goals
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
        categoryId TEXT NOT NULL,
        name TEXT NOT NULL,
        targetAmount REAL NOT NULL,
        currentAmount REAL NOT NULL DEFAULT 0.0,
        deadline TEXT,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        createdAt TEXT,
        updatedAt TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    // 8. Table Transfer Logs (chuẩn hóa transfer_logs)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transfer_logs (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        fromCategoryId TEXT NOT NULL,
        toCategoryId TEXT NOT NULL,
        note TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transfer_logs_createdAt ON transfer_logs(createdAt)',
    );

    // 9. Table Budgets History
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets_history (
        id TEXT PRIMARY KEY,
        monthYear TEXT NOT NULL,
        totalInflow REAL NOT NULL DEFAULT 0.0,
        totalOutflow REAL NOT NULL DEFAULT 0.0,
        rolloverMethod TEXT NOT NULL,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    // 10. Table User Profile Local
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT 'Người dùng',
        email TEXT,
        avatarPath TEXT,
        currencyCode TEXT NOT NULL DEFAULT 'VND',
        pinHash TEXT,
        isBiometricEnabled INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // Seed Data mặc định ban đầu theo SQLITE_SCHEMA_SPECIFICATION.md
    await db.execute('''
      INSERT OR IGNORE INTO category_types (id, name, priority, createdAt) VALUES 
      ('type_fixed', 'Cố định', 1, datetime('now')),
      ('type_essential', 'Thiết yếu', 2, datetime('now')),
      ('type_savings', 'Tiết kiệm', 3, datetime('now'))
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE offline_tasks_queue ADD COLUMN parsed_data TEXT',
      );
    }
    if (oldVersion < 3) {
      // Category Types
      await db.execute('''
        CREATE TABLE IF NOT EXISTS category_types(
          id TEXT PRIMARY KEY,
          name TEXT,
          priority INTEGER
        )
      ''');

      // Categories
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories(
          id TEXT PRIMARY KEY,
          categoryTypeId TEXT,
          name TEXT,
          iconName TEXT,
          color TEXT,
          defaultBudget REAL,
          isActive INTEGER
        )
      ''');

      // Monthly Budgets
      await db.execute('''
        CREATE TABLE IF NOT EXISTS monthly_budgets(
          id TEXT PRIMARY KEY,
          categoryId TEXT,
          monthYear TEXT,
          budgetedAmount REAL,
          rolloverAmount REAL,
          spentAmount REAL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mb_monthYear ON monthly_budgets(monthYear)',
      );

      // Monthly Summaries
      await db.execute('''
        CREATE TABLE IF NOT EXISTS monthly_summaries(
          id TEXT PRIMARY KEY,
          monthYear TEXT,
          totalIncome REAL,
          totalExpense REAL,
          unallocatedBalance REAL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ms_monthYear ON monthly_summaries(monthYear)',
      );

      // Goals
      await db.execute('''
        CREATE TABLE IF NOT EXISTS goals(
          id TEXT PRIMARY KEY,
          categoryId TEXT,
          name TEXT,
          targetAmount REAL,
          currentAmount REAL,
          deadline TEXT,
          status TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transferlogs(
          id TEXT PRIMARY KEY,
          amount REAL,
          fromCategoryId TEXT,
          toCategoryId TEXT,
          note TEXT,
          createdAt TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE offline_tasks_queue ADD COLUMN client_timestamp TEXT',
      );
    }
    if (oldVersion < 6) {
      // 1. Transaction Details (1:1 với transactions)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transaction_details (
          id TEXT PRIMARY KEY,
          transactionId TEXT NOT NULL UNIQUE,
          note TEXT,
          receiptFileId TEXT,
          rawInputText TEXT,
          confidenceScore REAL,
          createdAt TEXT,
          updatedAt TEXT,
          FOREIGN KEY (transactionId) REFERENCES transactions(id) ON DELETE CASCADE
        )
      ''');

      // 2. Transfer Logs (chuẩn hóa tên bảng)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transfer_logs (
          id TEXT PRIMARY KEY,
          amount REAL NOT NULL,
          fromCategoryId TEXT NOT NULL,
          toCategoryId TEXT NOT NULL,
          note TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transfer_logs_createdAt ON transfer_logs(createdAt)',
      );

      // Đồng bộ dữ liệu cũ từ transferlogs sang transfer_logs nếu có
      try {
        await db.execute('''
          INSERT OR IGNORE INTO transfer_logs (id, amount, fromCategoryId, toCategoryId, note, createdAt)
          SELECT id, amount, fromCategoryId, toCategoryId, note, createdAt FROM transferlogs
        ''');
      } catch (_) {}

      // 3. Budgets History
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets_history (
          id TEXT PRIMARY KEY,
          monthYear TEXT NOT NULL,
          totalInflow REAL NOT NULL DEFAULT 0.0,
          totalOutflow REAL NOT NULL DEFAULT 0.0,
          rolloverMethod TEXT NOT NULL,
          createdAt TEXT,
          updatedAt TEXT
        )
      ''');

      // 4. User Profile Local
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profile (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL DEFAULT 'Người dùng',
          avatarPath TEXT,
          currencyCode TEXT NOT NULL DEFAULT 'VND',
          pinHash TEXT,
          isBiometricEnabled INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL
        )
      ''');

      // 5. Bổ sung các cột mới vào categories nếu thiếu
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN targetAmount REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN deadline TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN createdAt TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN updatedAt TEXT');
      } catch (_) {}

      // 6. Đảm bảo indexes đầy đủ
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(categoryTypeId)',
        );
      } catch (_) {}
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status)',
        );
      } catch (_) {}
      try {
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_mb_category_month ON monthly_budgets(categoryId, monthYear)',
        );
      } catch (_) {}
    }

    if (oldVersion < 7) {
      await db.execute('DROP TABLE IF EXISTS offline_tasks_queue');
      await db.execute('DROP TABLE IF EXISTS app_cache');
      await db.execute('DROP TABLE IF EXISTS transferlogs');
    }

    if (oldVersion < 8) {
      await db.execute('PRAGMA foreign_keys = OFF;');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transactions_v8 (
          id TEXT PRIMARY KEY,
          categoryId TEXT,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          transactionDate TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'COMPLETED',
          note TEXT DEFAULT '',
          createdAt TEXT,
          updatedAt TEXT,
          FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        INSERT INTO transactions_v8 (id, categoryId, amount, type, transactionDate, status, note, createdAt, updatedAt)
        SELECT id, 
               CASE WHEN categoryId = '' OR categoryId = 'SYSTEM_ROLLOVER' THEN NULL ELSE categoryId END,
               amount, type, transactionDate, status, note, createdAt, updatedAt
        FROM transactions
      ''');
      await db.execute('DROP TABLE transactions');
      await db.execute('ALTER TABLE transactions_v8 RENAME TO transactions');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transactionDate)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(categoryId)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status)',
      );
      await db.execute('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transaction_details');
      await txn.delete('transactions');
      await txn.delete('monthly_budgets');
      await txn.delete('monthly_summaries');
      await txn.delete('goals');
      await txn.delete('transfer_logs');
      await txn.delete('budgets_history');
      await txn.delete('categories');
      await txn.delete('category_types');
    });
  }

  /// Lấy thông tin hồ sơ người dùng cục bộ
  Future<UserProfileModel?> getUserProfile([String? id]) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (id != null && id.isNotEmpty) {
      maps = await db.query(
        'user_profile',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
    } else {
      maps = await db.query('user_profile', limit: 1);
    }
    if (maps.isEmpty) return null;
    return UserProfileModel.fromMap(maps.first);
  }

  /// Lưu hoặc cập nhật hồ sơ người dùng vào SQLite
  Future<void> saveUserProfile(UserProfileModel profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Kiểm tra xem tài khoản / username đã tồn tại chưa
  Future<bool> userProfileExists(String id) async {
    final db = await database;
    final maps = await db.query(
      'user_profile',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Xóa hồ sơ người dùng
  Future<void> deleteUserProfile(String id) async {
    final db = await database;
    await db.delete('user_profile', where: 'id = ?', whereArgs: [id]);
  }
}
