import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:appintern/core/constants/app_keys.dart';

class StorageService extends GetxService {
  late GetStorage _box;

  // ============================================================
  // SECURE STORAGE — Dành cho dữ liệu nhạy cảm (userId, session)
  // ============================================================
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Cache in-memory để giữ API đồng bộ (read<T>) cho các caller hiện tại
  final Map<String, String> _secureCache = {};

  // Danh sách các key nhạy cảm phải lưu vào Secure Storage
  static const _sensitiveKeys = {
    AppKeys.isLoggedIn,
    AppKeys.userId,
    AppKeys.userName,
  };

  // Hàm khởi tạo chạy ngầm
  Future<StorageService> init() async {
    await GetStorage.init();
    _box = GetStorage();

    // Load toàn bộ sensitive data từ Secure Storage vào memory cache
    for (final key in _sensitiveKeys) {
      final value = await _secureStorage.read(key: key);
      if (value != null) {
        _secureCache[key] = value;
      }
    }

    // Migration: Nếu có dữ liệu cũ trong GetStorage, chuyển sang Secure
    await _migrateToSecureStorage();

    return this;
  }

  /// One-time migration: chuyển dữ liệu nhạy cảm từ GetStorage sang SecureStorage
  Future<void> _migrateToSecureStorage() async {
    for (final key in _sensitiveKeys) {
      final oldValue = _box.read(key);
      if (oldValue != null && !_secureCache.containsKey(key)) {
        final valueStr = oldValue.toString();
        await _secureStorage.write(key: key, value: valueStr);
        _secureCache[key] = valueStr;
        _box.remove(key); // Xóa khỏi GetStorage (plaintext)
      }
    }
  }

  // ============================================================
  // API ĐỌC/GHI THỐNG NHẤT
  // ============================================================

  /// Đọc dữ liệu (đồng bộ) — tự động đọc từ Secure hoặc Normal storage
  T? read<T>(String key) {
    if (_sensitiveKeys.contains(key)) {
      final raw = _secureCache[key];
      if (raw == null) return null;
      // Ép kiểu thủ công vì Secure Storage chỉ lưu String
      if (T == bool) return (raw == 'true') as T;
      if (T == int) return int.tryParse(raw) as T?;
      if (T == double) return double.tryParse(raw) as T?;
      return raw as T;
    }
    return _box.read<T>(key);
  }

  /// Ghi dữ liệu — tự động ghi vào Secure hoặc Normal storage
  void write(String key, dynamic value) {
    if (_sensitiveKeys.contains(key)) {
      final valueStr = value.toString();
      _secureCache[key] = valueStr;
      // Ghi async vào Secure Storage ngầm (fire-and-forget)
      _secureStorage.write(key: key, value: valueStr);
    } else {
      _box.write(key, value);
    }
  }

  /// Xóa một dữ liệu cụ thể
  void remove(String key) {
    if (_sensitiveKeys.contains(key)) {
      _secureCache.remove(key);
      _secureStorage.delete(key: key);
    } else {
      _box.remove(key);
    }
  }

  /// Xóa toàn bộ dữ liệu (Dùng khi Đăng xuất)
  void clearAll() {
    _box.erase();
    _secureCache.clear();
    _secureStorage.deleteAll();
  }
}
