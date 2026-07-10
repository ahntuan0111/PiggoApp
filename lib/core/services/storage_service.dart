import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StorageService extends GetxService {
  late GetStorage _box;

  // Hàm khởi tạo chạy ngầm
  Future<StorageService> init() async {
    await GetStorage.init();
    _box = GetStorage();
    return this;
  }

  // Đọc dữ liệu
  T? read<T>(String key) {
    return _box.read<T>(key);
  }

  // Ghi dữ liệu
  void write(String key, dynamic value) {
    _box.write(key, value);
  }

  // Xóa một dữ liệu cụ thể
  void remove(String key) {
    _box.remove(key);
  }

  // Xóa toàn bộ dữ liệu (Dùng khi Đăng xuất)
  void clearAll() {
    _box.erase();
  }
}
