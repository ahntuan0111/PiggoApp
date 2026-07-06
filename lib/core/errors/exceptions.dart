// Lỗi nghiệp vụ hoặc lỗi chung
class BaseException implements Exception {
  final String message;
  BaseException(this.message);
}

// Các exception trừu tượng ở tầng Core (Thuần túy, không dính dáng thư viện bên thứ 3)
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  final String? type;
  ServerException([this.message = "Lỗi máy chủ nội bộ.", this.statusCode, this.type]);
}

class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = "Không có kết nối Internet."]);
}

class CacheException implements Exception {
  final String message;
  CacheException([this.message = "Lỗi truy xuất bộ nhớ tạm."]);
}
