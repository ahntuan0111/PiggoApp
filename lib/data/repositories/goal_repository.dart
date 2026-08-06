import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';

class GoalRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;

  GoalRepository(this._appwrite);

  Future<List<GoalModel>> getGoals() async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.listRows(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.goalsTableId,
        queries: [Query.orderDesc('\$createdAt')],
      );

      return response.rows
          .map(
            (e) => GoalModel.fromMap(
              Map<String, dynamic>.from(e.data)..['\$id'] = e.$id,
            ),
          )
          .toList();
    });
  }

  Future<GoalModel> createGoal(GoalModel goal) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.createRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.goalsTableId,
        rowId: ID.unique(),
        data: goal.toMap(),
      );
      return GoalModel.fromMap(
        Map<String, dynamic>.from(response.data)..['\$id'] = response.$id,
      );
    });
  }

  Future<GoalModel> updateGoal(GoalModel goal) async {
    return handleAppwriteError(() async {
      final response = await _appwrite.tables.updateRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.goalsTableId,
        rowId: goal.id,
        data: goal.toMap(),
      );
      return GoalModel.fromMap(
        Map<String, dynamic>.from(response.data)..['\$id'] = response.$id,
      );
    });
  }

  Future<void> deleteGoal(String id) async {
    return handleAppwriteError(() async {
      await _appwrite.tables.deleteRow(
        databaseId: _appwrite.databaseId,
        tableId: _appwrite.goalsTableId,
        rowId: id,
      );
    });
  }
}
