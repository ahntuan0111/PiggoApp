import 'package:appintern/core/errors/exceptions.dart';
import 'package:appwrite/appwrite.dart';

mixin AppwriteErrorHandler {
  Future<T> handleAppwriteError<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AppwriteException catch (e) {
      // Bắt các lỗi của hệ thống Appwrite và ném lại thành lỗi nghiệp vụ của ứng dụng
      throw ServerException(e.message ?? "Lỗi máy chủ", e.code, e.type);
    } catch (e) {
      throw ServerException("Lỗi hệ thống không xác định: $e");
    }
  }
}
