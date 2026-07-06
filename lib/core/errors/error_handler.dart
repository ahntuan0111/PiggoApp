import 'package:dartz/dartz.dart';
import 'exceptions.dart';
import 'failure.dart';
import '/core/utils/logger.dart';

typedef FutureEither<T> = Future<Either<Failure, T>>;
typedef ApiCall<T> = Future<T> Function();

class ErrorHandler {
  /// Hàm dùng để bao bọc các gọi API, đã được tách biệt khỏi các thư viện bên thứ 3
  static FutureEither<T> execute<T>(
    ApiCall<T> call, {
    String tag = "API_SERVICE",
  }) async {
    try {
      final result = await call();
      AppLogger.success(tag, result);
      return right(result);
    } on NetworkException catch (e) {
      AppLogger.info(tag, "Mạng chập chờn, tự động thử lại sau 2 giây...");
      await Future.delayed(const Duration(seconds: 2));
      try {
        final result = await call();
        AppLogger.success(tag, result);
        return right(result);
      } catch (_) {
        AppLogger.error(tag, e.message);
        return left(Failure(message: e.message));
      }
    } on ServerException catch (e) {
      if (e.statusCode != null && e.statusCode! >= 500) {
        AppLogger.info(
          tag,
          "Lỗi server (${e.statusCode}), tự động thử lại sau 2 giây...",
        );
        await Future.delayed(const Duration(seconds: 2));
        try {
          final result = await call();
          AppLogger.success(tag, result);
          return right(result);
        } catch (_) {
          AppLogger.error(tag, e.message);
          return left(
            Failure(message: e.message, statusCode: e.statusCode, type: e.type),
          );
        }
      } else {
        AppLogger.error(tag, e.message);
        return left(
          Failure(message: e.message, statusCode: e.statusCode, type: e.type),
        );
      }
    } catch (e, stack) {
      final message = "Lỗi hệ thống không xác định: ${e.toString()}";
      AppLogger.error(tag, message, stack);
      return left(Failure(message: message));
    }
  }
}
