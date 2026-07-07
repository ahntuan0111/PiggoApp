import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/core/network/appwrite_service.dart';
import 'package:appintern/domain/repositories/appwrite_error_mixin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StorageRepository with AppwriteErrorHandler {
  final AppwriteService _appwrite;

  StorageRepository(this._appwrite);

  Future<String> uploadReceiptImage(File file) async {
    return handleAppwriteError(() async {
      String bucketId = dotenv.env['APPWRITE_RECEIPT_BUCKET_ID'] ?? _appwrite.avatarBucketId;
      
      final result = await _appwrite.storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(
          path: file.path,
          filename: file.path.split('/').last,
        ),
      );
      
      return result.$id;
    });
  }
}
