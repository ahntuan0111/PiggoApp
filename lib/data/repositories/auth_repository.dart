import 'dart:convert';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';
import 'package:appwrite/models.dart';
import 'package:appwrite/appwrite.dart';
import 'package:google_sign_in/google_sign_in.dart' as google;

class AuthRepository with AppwriteErrorHandler {
  final AppwriteService _appwriteService;

  AuthRepository(this._appwriteService);

  Future<User> getUser() async {
    return handleAppwriteError(
      () async => await _appwriteService.account.get(),
    );
  }

  Future<void> loginWithGoogle() async {
    return handleAppwriteError(() async {
      // 1. Mở giao diện chọn tài khoản Google của thiết bị
      final google.GoogleSignIn googleSignIn = google.GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId:
            '520092480732-g5mjid3nvkunl95pqttu9gj9uqe0g75j.apps.googleusercontent.com',
      );
      final google.GoogleSignInAccount? account = await googleSignIn
          .authenticate();

      if (account == null) {
        throw Exception("Người dùng đã hủy đăng nhập Google");
      }

      // 2. Lấy thông tin chứng thực (idToken)
      final google.GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        throw Exception("Không thể lấy ID Token từ Google");
      }

      final functionId = _appwriteService.functionGoogleSignIn;

      // 3. Gửi idToken lên Appwrite Cloud Function để đổi lấy Custom Token
      final execution = await _appwriteService.functions.createExecution(
        functionId: functionId,
        body: '{"idToken": "$idToken"}',
        xasync: false,
      );

      if (execution.responseStatusCode >= 400) {
        throw Exception("Lỗi chứng thực từ Server: ${execution.responseBody}");
      }

      // 4. Giải mã response lấy Custom Token
      final responseData = jsonDecode(execution.responseBody);
      final String customToken = responseData['secret'];
      final String userId = responseData['userId'];

      // 5. Dùng Custom Token để tạo Appwrite Session chính thức
      await _appwriteService.account.createSession(
        userId: userId,
        secret: customToken,
      );
    });
  }

  Future<void> logout() async {
    return handleAppwriteError(() async {
      await _appwriteService.account
          .deleteSession(sessionId: 'current')
          .catchError((_) => null);

      final google.GoogleSignIn googleSignIn = google.GoogleSignIn.instance;
      await googleSignIn.signOut().catchError((_) => null);
    });
  }

  Future<void> clearAllUserData() async {
    return handleAppwriteError(() async {
      final tables = [
        _appwriteService.transactionsTableId,
        _appwriteService.transactionDetailsTableId,
        _appwriteService.monthlyBudgetsTableId,
        _appwriteService.monthlySummariesTableId,
        _appwriteService.transferLogsTableId,
        _appwriteService.goalsTableId,
        _appwriteService.categoriesTableId,
        _appwriteService.categoriesTypeTableId,
      ];

      for (var tableId in tables) {
        while (true) {
          final response = await _appwriteService.databases.listDocuments(
            databaseId: _appwriteService.databaseId,
            collectionId: tableId,
            queries: [Query.limit(100)],
          );
          if (response.documents.isEmpty) break;
          for (var doc in response.documents) {
            await _appwriteService.databases
                .deleteDocument(
                  databaseId: _appwriteService.databaseId,
                  collectionId: tableId,
                  documentId: doc.$id,
                )
                .catchError((_) => null);
          }
        }
      }
    });
  }
}
