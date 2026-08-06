import 'package:appintern/core/errors/exceptions.dart';
import 'package:appwrite/appwrite.dart';

mixin AppwriteErrorHandler {
  Future<T> handleAppwriteError<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AppwriteException catch (e) {
      if (e.message != null &&
          (e.message!.contains('SocketException') ||
              e.message!.contains('Network is unreachable'))) {
        throw NetworkException("Không có kết nối mạng, vui lòng kiểm tra lại.");
      }
      // Bắt các lỗi của hệ thống Appwrite và ném lại thành lỗi nghiệp vụ của ứng dụng
      throw ServerException(e.message ?? "Lỗi máy chủ", e.code, e.type);
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable')) {
        throw NetworkException("Không có kết nối mạng, vui lòng kiểm tra lại.");
      }
      throw ServerException("Lỗi hệ thống không xác định: $e");
    }
  }
}
