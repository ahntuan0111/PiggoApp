import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:get/get.dart';

class GoalRepository {
  GoalRepository();

  Future<List<GoalModel>> getGoals({List<String>? categoryIds}) async {
    final localDb = Get.find<LocalDatabaseService>();
    final rows = await localDb.getGoals();
    var list = rows.map((e) => GoalModel.fromMap(e)).toList();

    if (categoryIds != null) {
      if (categoryIds.isEmpty) return [];
      list = list.where((g) => categoryIds.contains(g.categoryId)).toList();
    }

    return list;
  }

  Future<GoalModel> createGoal(GoalModel goal, [String? userId]) async {
    final localDb = Get.find<LocalDatabaseService>();
    final goalToInsert = goal.id.isEmpty
        ? goal.copyWith(id: 'goal_${DateTime.now().millisecondsSinceEpoch}')
        : goal;

    await localDb.insertLocalGoal(goalToInsert.toMap());
    return goalToInsert;
  }

  Future<GoalModel> updateGoal(GoalModel goal) async {
    final localDb = Get.find<LocalDatabaseService>();
    await localDb.updateLocalGoal(goal.toMap());
    return goal;
  }

  Future<void> deleteGoal(String id) async {
    final localDb = Get.find<LocalDatabaseService>();
    await localDb.deleteLocalGoal(id);
  }
}
