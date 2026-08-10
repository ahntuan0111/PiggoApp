import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'local_database_base.dart';
import 'local_db_cache_mixin.dart';
import 'local_db_transaction_mixin.dart';
import 'local_db_offline_queue_mixin.dart';
import 'local_db_category_mixin.dart';
import 'local_db_budget_mixin.dart';
import 'local_db_goal_mixin.dart';

class LocalDatabaseService extends LocalDatabaseBase
    with
        LocalDbCacheMixin,
        LocalDbTransactionMixin,
        LocalDbOfflineQueueMixin,
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
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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
        parsed_data TEXT,
        client_timestamp TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_queue_status ON offline_tasks_queue(status)',
    );

    // 3. Table App Cache (Dành cho các thông tin không cần structured table)
    await db.execute('''
      CREATE TABLE app_cache(
        key TEXT PRIMARY KEY,
        json_data TEXT
      )
    ''');

    // 4. Category Types
    await db.execute('''
      CREATE TABLE category_types(
        id TEXT PRIMARY KEY,
        name TEXT,
        priority INTEGER
      )
    ''');

    // 5. Categories
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        categoryTypeId TEXT,
        name TEXT,
        iconName TEXT,
        color TEXT,
        defaultBudget REAL,
        isActive INTEGER
      )
    ''');

    // 6. Monthly Budgets
    await db.execute('''
      CREATE TABLE monthly_budgets(
        id TEXT PRIMARY KEY,
        categoryId TEXT,
        monthYear TEXT,
        budgetedAmount REAL,
        rolloverAmount REAL,
        spentAmount REAL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_mb_monthYear ON monthly_budgets(monthYear)',
    );

    // 7. Monthly Summaries
    await db.execute('''
      CREATE TABLE monthly_summaries(
        id TEXT PRIMARY KEY,
        monthYear TEXT,
        totalIncome REAL,
        totalExpense REAL,
        unallocatedBalance REAL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_ms_monthYear ON monthly_summaries(monthYear)',
    );

    // 8. Goals
    await db.execute('''
      CREATE TABLE goals(
        id TEXT PRIMARY KEY,
        categoryId TEXT,
        name TEXT,
        targetAmount REAL,
        currentAmount REAL,
        deadline TEXT,
        status TEXT
      )
    ''');
    // 9. Transfer Logs
    await db.execute('''
      CREATE TABLE transferlogs(
        id TEXT PRIMARY KEY,
        amount REAL,
        fromCategoryId TEXT,
        toCategoryId TEXT,
        note TEXT,
        createdAt TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE offline_tasks_queue ADD COLUMN parsed_data TEXT',
      );
    }
    if (oldVersion < 3) {
      // 4. Category Types
      await db.execute('''
        CREATE TABLE IF NOT EXISTS category_types(
          id TEXT PRIMARY KEY,
          name TEXT,
          priority INTEGER
        )
      ''');

      // 5. Categories
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

      // 6. Monthly Budgets
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

      // 7. Monthly Summaries
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

      // 8. Goals
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
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('offline_tasks_queue');
      await txn.delete('app_cache');
      await txn.delete('category_types');
      await txn.delete('categories');
      await txn.delete('monthly_budgets');
      await txn.delete('monthly_summaries');
      await txn.delete('goals');
      await txn.delete('transferlogs');
    });
  }
}
