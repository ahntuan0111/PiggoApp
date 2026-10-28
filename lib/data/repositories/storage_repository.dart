import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Repository quản lý lưu trữ tệp tin hóa đơn cục bộ (Local Storage Layer).
/// Lưu trữ ảnh biên lai trong thư mục an toàn của ứng dụng (`<ApplicationDocumentsDirectory>/receipts`).
/// Hoàn toàn ngoại tuyến, không tốn băng thông, không phụ thuộc máy chủ.
class StorageRepository {
  StorageRepository();

  /// Lấy thư mục lưu trữ ảnh biên lai cục bộ: `<app_documents>/receipts`
  Future<Directory> get receiptsDirectory async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'receipts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Lấy thư mục lưu trữ ảnh đại diện cục bộ: `<app_documents>/avatars`
  Future<Directory> get avatarsDirectory async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'avatars'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Lưu ảnh đại diện vào thư mục cục bộ avatars/
  /// Trả về đường dẫn tuyệt đối của file ảnh
  Future<String> saveAvatarImage(File file, String userId) async {
    if (!await file.exists()) {
      throw FileSystemException('Tệp tin không tồn tại', file.path);
    }

    final targetDir = await avatarsDirectory;
    final ext = p.extension(file.path);
    final safeExt = ext.isNotEmpty ? ext : '.jpg';
    final safeUserId = userId.replaceAll(RegExp(r'[^\w]'), '_');
    final fileName = 'avatar_${safeUserId}_${DateTime.now().millisecondsSinceEpoch}$safeExt';
    final targetPath = p.join(targetDir.path, fileName);

    await file.copy(targetPath);
    return targetPath;
  }

  /// Lưu ảnh hóa đơn vào thư mục cục bộ receipts/
  /// Trả về tên file (vd: receipt_1712345678901.jpg)
  Future<String> uploadReceiptImage(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('Tệp tin không tồn tại', file.path);
    }

    final targetDir = await receiptsDirectory;
    final ext = p.extension(file.path);
    final safeExt = ext.isNotEmpty ? ext : '.jpg';
    final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}$safeExt';
    final targetPath = p.join(targetDir.path, fileName);

    await file.copy(targetPath);
    return fileName;
  }

  /// Đọc dữ liệu bytes của file ảnh để hiển thị lên UI qua Image.memory
  Future<List<int>> getFileView(String fileId) async {
    final file = await resolveReceiptFile(fileId);
    if (file != null && await file.exists()) {
      return await file.readAsBytes();
    }
    throw FileSystemException('Không tìm thấy tệp ảnh biên lai', fileId);
  }

  /// Lấy đường dẫn file ảnh cục bộ
  String getImageUrl(String fileId) {
    if (fileId.isEmpty) return '';
    if (p.isAbsolute(fileId) || fileId.contains(':\\') || fileId.startsWith('file://')) {
      return fileId.replaceFirst('file://', '');
    }
    return fileId;
  }

  /// Xóa file ảnh vật lý khỏi bộ nhớ máy theo Q6 (Lựa chọn A: Xóa vĩnh viễn)
  Future<void> deleteFile(String fileId) async {
    try {
      final file = await resolveReceiptFile(fileId);
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[StorageRepository] Lỗi khi xóa file $fileId: $e');
    }
  }

  /// Helper giải quyết đường dẫn file linh hoạt (tên file hoặc đường dẫn tuyệt đối)
  Future<File?> resolveReceiptFile(String fileId) async {
    if (fileId.trim().isEmpty) return null;

    final cleanId = fileId.replaceFirst('file://', '').trim();

    // 1. Nếu là đường dẫn tuyệt đối và file tồn tại
    final directFile = File(cleanId);
    if (await directFile.exists()) {
      return directFile;
    }

    // 2. Tìm trong thư mục receipts/
    final targetDir = await receiptsDirectory;
    final inReceiptsFile = File(p.join(targetDir.path, p.basename(cleanId)));
    if (await inReceiptsFile.exists()) {
      return inReceiptsFile;
    }

    return inReceiptsFile;
  }
}
