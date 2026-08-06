import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StorageRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;

  StorageRepository(this._appwrite);

  Future<String> uploadReceiptImage(File file) async {
    return handleAppwriteError(() async {
      String bucketId =
          dotenv.env['APPWRITE_RECEIPT_BUCKET_ID'] ?? _appwrite.avatarBucketId;

      String generatedFileId = ID.unique();

      return await _appwrite.storage
          .createFile(
            bucketId: bucketId,
            fileId: generatedFileId,
            file: InputFile.fromPath(
              path: file.path,
              filename: file.path.split('/').last,
            ),
          )
          .then((result) => result.$id)
          .catchError((e) {
            // Appwrite SDK có thể gặp lỗi parse JSON response khi upload file (thường do field thiếu)
            // Dù file ĐÃ ĐƯỢC UPLOAD THÀNH CÔNG lên server (trả về 201), SDK vẫn văng TypeError.
            // Ta catch TypeError này và trả về ID tự sinh để không làm gián đoạn luồng app.
            if (e is TypeError &&
                e.toString().contains(
                  "type 'Null' is not a subtype of type 'int'",
                )) {
              return generatedFileId;
            }
            throw e;
          });
    });
  }

  Future<List<int>> getFileView(String fileId) async {
    return handleAppwriteError(() async {
      String bucketId =
          dotenv.env['APPWRITE_RECEIPT_BUCKET_ID'] ?? _appwrite.avatarBucketId;
      return await _appwrite.storage.getFileView(
        bucketId: bucketId,
        fileId: fileId,
      );
    });
  }

  String getImageUrl(String fileId) {
    final bucketId =
        dotenv.env['APPWRITE_RECEIPT_BUCKET_ID'] ?? _appwrite.avatarBucketId;
    final projectId = _appwrite.projectId;
    return '${_appwrite.client.endPoint}/storage/buckets/$bucketId/files/$fileId/view?project=$projectId';
  }

  Future<void> deleteFile(String fileId) async {
    return handleAppwriteError(() async {
      String bucketId =
          dotenv.env['APPWRITE_RECEIPT_BUCKET_ID'] ?? _appwrite.avatarBucketId;
      await _appwrite.storage.deleteFile(bucketId: bucketId, fileId: fileId);
    });
  }
}
