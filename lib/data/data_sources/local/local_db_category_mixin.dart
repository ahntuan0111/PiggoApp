import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';

mixin LocalDbCategoryMixin on LocalDatabaseBase {
  // ==========================================
  // CATEGORIES & TYPES
  // ==========================================
  Future<void> saveCategoryTypes(
    List<Map<String, dynamic>> types, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    Batch batch = db.batch();

    for (var type in types) {
      batch.insert('category_types', {
        'id': type['id'],
        'userId': type['userId'] ?? effectiveUserId,
        'name': type['name'],
        'priority': type['priority'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertCategoryType(
    Map<String, dynamic> type, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    await db.insert(
      'category_types',
      {
        'id': type['id'],
        'userId': type['userId'] ?? effectiveUserId,
        'name': type['name'],
        'priority': type['priority'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCategoryTypes({String? userId}) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    return await db.query(
      'category_types',
      where: 'userId = ?',
      whereArgs: [effectiveUserId],
      orderBy: 'priority ASC',
    );
  }

  Future<void> saveCategories(
    List<Map<String, dynamic>> cats, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    Batch batch = db.batch();

    for (var cat in cats) {
      batch.insert('categories', {
        'id': cat['id'],
        'userId': cat['userId'] ?? effectiveUserId,
        'categoryTypeId': cat['categoryTypeId'] ?? cat['categoryTypes'],
        'name': cat['name'],
        'iconName': cat['iconName'],
        'color': cat['color'],
        'defaultBudget': cat['defaultBudget'],
        'targetAmount': cat['targetAmount'],
        'deadline': cat['deadline'],
        'isActive': cat['isActive'] == true || cat['isActive'] == 1 ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCategories({String? userId}) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    final results = await db.query(
      'categories',
      where: 'userId = ?',
      whereArgs: [effectiveUserId],
    );
    return results.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['isActive'] = map['isActive'] == 1;
      return map;
    }).toList();
  }

  Future<void> insertLocalCategory(
    Map<String, dynamic> cat, {
    String? userId,
  }) async {
    final effectiveUserId = userId ?? currentUserId;
    final db = await database;
    await db.insert(
      'categories',
      {
        'id': cat['id'],
        'userId': cat['userId'] ?? effectiveUserId,
        'categoryTypeId': cat['categoryTypeId'] ?? cat['categoryTypes'],
        'name': cat['name'],
        'iconName': cat['iconName'],
        'color': cat['color'],
        'defaultBudget': cat['defaultBudget'],
        'targetAmount': cat['targetAmount'],
        'deadline': cat['deadline'],
        'isActive': cat['isActive'] == true || cat['isActive'] == 1 ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCategory(
    String categoryId,
    String name,
    String iconName,
    String color, {
    String? userId,
  }) async {
    final db = await database;
    final whereClause = userId != null ? 'id = ? AND userId = ?' : 'id = ?';
    final whereArgs = userId != null ? [categoryId, userId] : [categoryId];
    await db.update(
      'categories',
      {'name': name, 'iconName': iconName, 'color': color},
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  Future<void> updateCategoryType(
    String typeId,
    String name, {
    String? userId,
  }) async {
    final db = await database;
    final whereClause = userId != null ? 'id = ? AND userId = ?' : 'id = ?';
    final whereArgs = userId != null ? [typeId, userId] : [typeId];
    await db.update(
      'category_types',
      {'name': name},
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  Future<void> deleteCategory(String categoryId, {String? userId}) async {
    final db = await database;
    final whereClause = userId != null ? 'id = ? AND userId = ?' : 'id = ?';
    final whereArgs = userId != null ? [categoryId, userId] : [categoryId];
    await db.update(
      'categories',
      {
        'isActive': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  Future<void> deleteCategoryType(String typeId, {String? userId}) async {
    final db = await database;
    final whereClause = userId != null ? 'id = ? AND userId = ?' : 'id = ?';
    final whereArgs = userId != null ? [typeId, userId] : [typeId];
    await db.delete('category_types', where: whereClause, whereArgs: whereArgs);
  }
}
