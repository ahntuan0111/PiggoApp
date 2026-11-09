import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:get/get.dart';

class GoalRepository {
  GoalRepository();

  Future<List<GoalModel>> getGoals({
    List<String>? categoryIds,
    String? userId,
  }) async {
    final localDb = Get.find<LocalDatabaseService>();
    final rows = await localDb.getGoals(userId: userId);
    var list = rows.map((e) => GoalModel.fromMap(e)).toList();

    if (categoryIds != null) {
      if (categoryIds.isEmpty) return [];
      list = list.where((g) => categoryIds.contains(g.categoryId)).toList();
    }

    return list;
  }

  Future<GoalModel> createGoal(GoalModel goal, [String? userId]) async {
    final localDb = Get.find<LocalDatabaseService>();
    final uid = userId ?? goal.userId ?? localDb.currentUserId;
    final goalToInsert = goal.id.isEmpty
        ? goal.copyWith(
            id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
            userId: uid,
          )
        : (goal.userId == null ? goal.copyWith(userId: uid) : goal);

    await localDb.insertLocalGoal(goalToInsert.toMap(), userId: uid);
    return goalToInsert;
  }

  Future<GoalModel> updateGoal(GoalModel goal, {String? userId}) async {
    final localDb = Get.find<LocalDatabaseService>();
    await localDb.updateLocalGoal(goal.toMap(), userId: userId ?? goal.userId);
    return goal;
  }

  Future<void> deleteGoal(String id, {String? userId}) async {
    final localDb = Get.find<LocalDatabaseService>();
    await localDb.deleteLocalGoal(id, userId: userId);
  }
}
