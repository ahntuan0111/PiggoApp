import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';

class GoalRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;

  GoalRepository(this._appwrite);

  Future<List<GoalModel>> getGoals() async {
    return handleAppwriteError(() async {
      final response = await _appwrite.databases.listDocuments(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.goalsTableId,
        queries: [Query.orderDesc('\$createdAt')],
      );

      return response.documents
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
      final data = goal.toMap();
      data.remove('id');
      
      final response = await _appwrite.databases.createDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.goalsTableId,
        documentId: ID.unique(),
        data: data,
      );
      return GoalModel.fromMap(
        Map<String, dynamic>.from(response.data)..['\$id'] = response.$id,
      );
    });
  }

  Future<GoalModel> updateGoal(GoalModel goal) async {
    return handleAppwriteError(() async {
      final data = goal.toMap();
      data.remove('id');
      
      final response = await _appwrite.databases.updateDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.goalsTableId,
        documentId: goal.id,
        data: data,
      );
      return GoalModel.fromMap(
        Map<String, dynamic>.from(response.data)..['\$id'] = response.$id,
      );
    });
  }

  Future<void> deleteGoal(String id) async {
    return handleAppwriteError(() async {
      await _appwrite.databases.deleteDocument(
        databaseId: _appwrite.databaseId,
        collectionId: _appwrite.goalsTableId,
        documentId: id,
      );
    });
  }
}
