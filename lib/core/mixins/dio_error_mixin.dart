import 'package:dio/dio.dart';
import 'package:appintern/core/errors/exceptions.dart';

mixin DioErrorHandler {
  Future<T> handleDioError<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkException("Không thể kết nối đến máy chủ AI (Timeout).");
      }
      
      String message = "Lỗi máy chủ AI.";
      if (e.response != null && e.response?.data != null) {
        try {
          message = e.response?.data['message'] ?? e.response?.data['detail'] ?? message;
        } catch (_) {}
      }

      throw ServerException(
        message,
        e.response?.statusCode,
        "DIO_ERROR",
      );
    } catch (e) {
      throw ServerException("Lỗi hệ thống không xác định (STT): $e");
    }
  }
}
