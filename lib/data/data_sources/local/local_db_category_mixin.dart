import 'package:appintern/data/data_sources/local/local_database_base.dart';
import 'package:sqflite/sqflite.dart';

mixin LocalDbCategoryMixin on LocalDatabaseBase {
  // ==========================================
  // CATEGORIES & TYPES
  // ==========================================
  Future<void> saveCategoryTypes(List<Map<String, dynamic>> types) async {
    final db = await database;
    Batch batch = db.batch();

    // Purge logic: Xóa các records đã sync (bảo toàn offline ghosts)
    batch.delete('category_types', where: "id NOT LIKE 'offline_%'");

    for (var type in types) {
      batch.insert('category_types', {
        'id': type['id'],
        'ownerId': type['ownerId'],
        'name': type['name'],
        'priority': type['priority'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCategoryTypes() async {
    final db = await database;
    return await db.query('category_types', orderBy: 'priority ASC');
  }

  Future<void> saveCategories(List<Map<String, dynamic>> cats) async {
    final db = await database;
    Batch batch = db.batch();

    // Purge logic: Xóa các records đã sync (bảo toàn offline ghosts)
    batch.delete('categories', where: "id NOT LIKE 'offline_%'");

    for (var cat in cats) {
      batch.insert('categories', {
        'id': cat['id'],
        'categoryTypeId': cat['categoryTypes'] ?? cat['categoryTypeId'],
        'name': cat['name'],
        'iconName': cat['iconName'],
        'color': cat['color'],
        'defaultBudget': cat['defaultBudget'],
        'isActive': cat['isActive'] == true ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    final results = await db.query('categories');
    return results.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['isActive'] = map['isActive'] == 1;
      return map;
    }).toList();
  }

  Future<void> updateCategory(
    String categoryId,
    String name,
    String iconName,
    String color,
  ) async {
    final db = await database;
    await db.update(
      'categories',
      {'name': name, 'iconName': iconName, 'color': color},
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  Future<void> updateCategoryType(String typeId, String name) async {
    final db = await database;
    await db.update(
      'category_types',
      {'name': name},
      where: 'id = ?',
      whereArgs: [typeId],
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
  }

  Future<void> deleteCategoryType(String typeId) async {
    final db = await database;
    await db.delete('category_types', where: 'id = ?', whereArgs: [typeId]);
  }
}
