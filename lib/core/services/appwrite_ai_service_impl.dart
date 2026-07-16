import 'dart:convert';
import 'dart:developer' as dev;
import 'package:get/get.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appintern/domain/services/i_ai_service.dart';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:appintern/core/mixins/appwrite_error_mixin.dart';

class AppwriteAIServiceImpl extends GetxService with AppwriteErrorHandler implements IAIService {
  final AppwriteService _appwriteService = Get.find<AppwriteService>();
  final dio.Dio _dio = dio.Dio();

  AppwriteAIServiceImpl();

  @override
  Future<List<Map<String, dynamic>>> parseTransactionText({
    required String text,
    required List<String> availableCategories,
    required String currentTime,
  }) async {
    return handleAppwriteError(() async {
      final payload = {
        'text': text,
        'categories': availableCategories,
        'currentTime': currentTime,
      };

      String? envFunctionId = dotenv.env['APPWRITE_FUNCTION_PARSE_TRANSACTION'];
      final functionId = (envFunctionId != null && envFunctionId.isNotEmpty) 
          ? envFunctionId 
          : 'parse-transaction';

      dev.log('[AI_SERVICE] Calling function: $functionId', name: 'PARSE_TRANSACTION');
      dev.log('[AI_SERVICE] Payload text: "$text"', name: 'PARSE_TRANSACTION');

      final execution = await _appwriteService.functions.createExecution(
        functionId: functionId,
        body: jsonEncode(payload),
        xasync: false,
      );

      // ─── Log toàn bộ chi tiết execution để debug ───────────────────────
      dev.log('[AI_SERVICE] ── Execution Result ──', name: 'PARSE_TRANSACTION');
      dev.log('[AI_SERVICE] Status:         ${execution.status}', name: 'PARSE_TRANSACTION');
      dev.log('[AI_SERVICE] HTTP Code:      ${execution.responseStatusCode}', name: 'PARSE_TRANSACTION');
      dev.log('[AI_SERVICE] ResponseBody:   "${execution.responseBody}"', name: 'PARSE_TRANSACTION');
      dev.log('[AI_SERVICE] Logs:           ${execution.logs}', name: 'PARSE_TRANSACTION');
      dev.log('[AI_SERVICE] Errors:         ${execution.errors}', name: 'PARSE_TRANSACTION');
      // ────────────────────────────────────────────────────────────────────

      if (execution.responseStatusCode >= 400) {
        final serverMessage = (execution.responseBody.isNotEmpty)
            ? _tryParseMessage(execution.responseBody)
            : 'Server trả về lỗi ${execution.responseStatusCode} (body rỗng). Kiểm tra Logs Appwrite.';

        dev.log('[AI_SERVICE] ERROR: $serverMessage', name: 'PARSE_TRANSACTION');
        throw Exception('Function failed: $serverMessage');
      }

      final responseBody = execution.responseBody;
      if (responseBody.isNotEmpty) {
        final Map<String, dynamic> result = jsonDecode(responseBody);
        if (result['success'] == true && result['data'] != null) {
          dev.log('[AI_SERVICE] SUCCESS: ${result['data']}', name: 'PARSE_TRANSACTION');
          final data = result['data'] as Map<String, dynamic>;
          final List<dynamic> txs = data['transactions'] ?? [];
          return txs.map((e) => e as Map<String, dynamic>).toList();
        } else {
          final msg = result['message'] ?? 'Lỗi không xác định từ AI Server';
          throw Exception(msg);
        }
      } else {
        throw Exception('Function trả về kết quả rỗng (status: ${execution.responseStatusCode})');
      }
    });
  }

  /// Cố parse JSON để lấy field "message", nếu không được thì trả nguyên chuỗi
  String _tryParseMessage(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      return map['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }

  @override
  Future<String> convertSpeechToText(String audioPath) async {
    final file = await dio.MultipartFile.fromFile(audioPath, filename: 'voice_input.wav');
    final formData = dio.FormData.fromMap({'file': file});
    
    // Lấy IP cấu hình từ .env, fallback về localhost/10.0.2.2 nếu chưa set
    String? envSttUrl = dotenv.env['FASTAPI_STT_URL'];
    String baseUrl = (envSttUrl != null && envSttUrl.isNotEmpty) 
        ? envSttUrl 
        : (Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://localhost:8000');
    
    final sttResponse = await _dio.post(
      '$baseUrl/api/v1/transactions/voice',
      data: formData,
      options: dio.Options(
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
      )
    );
    
    if (sttResponse.data['status'] == 'success') {
      final text = sttResponse.data['raw_text_detected'] ?? "";
      if (text.isEmpty) {
        throw Exception("Không nghe rõ bạn nói gì.");
      }
      return text;
    } else {
      throw Exception("Lỗi từ server STT");
    }
  }
}
