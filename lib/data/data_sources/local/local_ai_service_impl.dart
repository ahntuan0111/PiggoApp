import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:appintern/domain/services/i_ai_service.dart';
import 'package:appintern/core/utils/local_rule_based_transaction_parser.dart';
import 'package:appintern/core/mixins/dio_error_mixin.dart';
import 'package:appintern/core/errors/exceptions.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/device_memory_service.dart';
import 'package:appintern/core/services/model_download_manager.dart';
import 'package:appintern/core/utils/transaction_router.dart';
import 'package:appintern/core/utils/dart_validation_layer.dart';
import 'package:appintern/data/data_sources/local/ai_engines/on_device_ai_engine.dart';

/// Triển khai AI & OCR Độc lập (Phase 5) — KIẾN TRÚC ON-DEVICE FIRST
/// Hỗ trợ cơ chế Fallback Đa Tầng ON-DEVICE FIRST (3-Tier Graceful Degradation):
///   - Tier 1: 100% Cục bộ On-Device (LocalRuleBasedTransactionParser + ML Kit OCR) - 0 VND, 0 Token, Offline, < 1ms
///   - Tier 2: Groq Cloud AI (Text: openai/gpt-oss-20b, Vision: qwen/qwen3.8-27b, STT: whisper-large-v3-turbo) - 0 VND
///   - Tier 3: Google Gemini 2.5 Flash (Dự phòng cuối khi Groq bị Rate Limit 429 / Timeout) - 0 VND
class LocalAIServiceImpl extends GetxService
    with DioErrorHandler
    implements IAIService {
  final dio.Dio _dio = dio.Dio(
    dio.BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  String? get _groqApiKey => dotenv.env['GROQ_API_KEY'];
  String? get _geminiApiKey => dotenv.env['GEMINI_API_KEY'];

  IOnDeviceAiEngine? _aiEngine;

  /// Thiết lập Engine AI On-Device (phục vụ DI hoặc testing)
  void setAiEngine(IOnDeviceAiEngine? engine) {
    _aiEngine = engine;
  }

  /// Kiểm tra thiết bị đang offline
  bool get _isOffline {
    try {
      return Get.find<NetworkService>().isOffline.value;
    } catch (_) {
      return false; // Nếu NetworkService chưa khởi tạo, coi như online
    }
  }

  /// Kiểm tra kết quả On-Device có đủ tốt không (có ít nhất 1 item với amount > 0)
  bool _isOnDeviceResultValid(List<Map<String, dynamic>> result) {
    return result.isNotEmpty &&
        result.any(
          (item) =>
              (item['amount'] as num?) != null && (item['amount'] as num) > 0,
        );
  }

  // ===========================================================================
  // TASK 5-2: Groq Whisper Cloud API cho Speech-to-Text
  // ===========================================================================
  @override
  Future<String> convertSpeechToText(String audioPath) async {
    return handleDioError(() async {
      final apiKey = _groqApiKey;
      if (apiKey == null || apiKey.trim().isEmpty) {
        throw ServerException(
          'Chưa cấu hình GROQ_API_KEY trong file .env. '
          'Vui lòng cấu hình API Key miễn phí từ https://console.groq.com hoặc sử dụng nhận diện giọng nói bàn phím.',
        );
      }

      final file = File(audioPath);
      if (!await file.exists()) {
        throw BaseException('Không tìm thấy file âm thanh ghi âm.');
      }

      final multipartFile = await dio.MultipartFile.fromFile(
        audioPath,
        filename: 'voice_input.wav',
      );

      final formData = dio.FormData.fromMap({
        'file': multipartFile,
        'model': 'whisper-large-v3-turbo',
        'language': 'vi',
        'response_format': 'json',
      });

      final response = await _dio.post(
        'https://api.groq.com/openai/v1/audio/transcriptions',
        data: formData,
        options: dio.Options(
          headers: {'Authorization': 'Bearer ${apiKey.trim()}'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final text = response.data['text']?.toString().trim() ?? '';
        if (text.isEmpty) {
          throw BaseException(
            'Không nhận diện được giọng nói trong đoạn ghi âm.',
          );
        }
        return text;
      } else {
        throw ServerException(
          'Lỗi từ Groq Whisper API (Mã ${response.statusCode}): ${response.statusMessage}',
          response.statusCode,
        );
      }
    });
  }

  // ===========================================================================
  // TASK 5-3 & 5-7: Phân tích Văn bản Giao dịch (Text Parsing) — ON-DEVICE FIRST
  // ===========================================================================
  @override
  Future<List<Map<String, dynamic>>> parseTransactionText({
    required String text,
    required List<String> availableCategories,
    required String currentTime,
  }) async {
    final cleanInput = text.trim();
    if (cleanInput.isEmpty) return [];

    // ═══════════════════════════════════════════════════════════════════
    // TẦNG 1: HYBRID ROUTER ON-DEVICE (Fast Path: Dart Engine | Smart Path: On-Device AI)
    // ═══════════════════════════════════════════════════════════════════
    final routeDecision = TransactionRouter.route(cleanInput);
    dev.log(
      '[LocalAIService] Router phân loại: ${routeDecision.routeType} (${routeDecision.reason})',
    );

    // 1a. Smart Path: Khi là câu phức tạp, kiểm tra điều kiện chạy AI On-Device
    if (routeDecision.isSmartPath) {
      bool isModelReady = false;
      bool isMemorySafe = false;

      try {
        if (Get.isRegistered<ModelDownloadManager>()) {
          isModelReady = Get.find<ModelDownloadManager>().isModelReady;
        }
        if (Get.isRegistered<DeviceMemoryService>()) {
          isMemorySafe = await Get.find<DeviceMemoryService>()
              .isSafeToLoadAiModel();
        } else {
          isMemorySafe = true;
        }
      } catch (_) {}

      final engine =
          _aiEngine ??
          (Get.isRegistered<IOnDeviceAiEngine>()
              ? Get.find<IOnDeviceAiEngine>()
              : null);

      if (isModelReady && isMemorySafe && engine != null) {
        try {
          dev.log(
            '[LocalAIService] 🧠 Chạy Smart Path: On-Device AI (${engine.modelName})...',
          );
          final rawAiItems = await engine
              .parse(cleanInput)
              .timeout(const Duration(milliseconds: 1200));

          final validated = DartValidationLayer.validateAndEnrich(
            rawInput: cleanInput,
            aiItems: rawAiItems,
            availableCategories: availableCategories,
            currentTime: currentTime,
          );

          if (_isOnDeviceResultValid(validated)) {
            dev.log(
              '[LocalAIService] ✅ Smart Path AI thành công và đã qua Dart Validation',
            );
            return validated;
          }
        } catch (e) {
          dev.log(
            '[LocalAIService] ⚠️ Smart Path AI thất bại hoặc timeout, fallback về Dart Engine: $e',
          );
        }
      }
    }

    // 1b. Fast Path (hoặc Fallback an toàn về Dart Engine)
    dev.log(
      '[LocalAIService] ⚡ Chạy Dart Engine: LocalRuleBasedTransactionParser (< 1ms)',
    );
    final onDeviceResult = LocalRuleBasedTransactionParser.parse(
      text: cleanInput,
      availableCategories: availableCategories,
      currentTime: currentTime,
    );

    if (_isOnDeviceResultValid(onDeviceResult)) {
      dev.log('[LocalAIService] ✅ On-Device thành công — amount > 0, hoàn tất');
      return onDeviceResult;
    }

    dev.log(
      '[LocalAIService] ⚠️ On-Device không bóc tách được amount > 0, thử Cloud...',
    );

    // Nếu đang offline, trả kết quả On-Device ngay (dù amount = 0)
    if (_isOffline) {
      dev.log(
        '[LocalAIService] 📡 Đang offline — trả kết quả On-Device mặc định',
      );
      return onDeviceResult;
    }

    // ═══════════════════════════════════════════════════════════════════
    // TẦNG 2: Groq Cloud AI (openai/gpt-oss-20b → llama-3.1-8b-instant)
    // Chỉ gọi khi On-Device không xử lý được & có mạng
    // ═══════════════════════════════════════════════════════════════════
    if (_groqApiKey != null && _groqApiKey!.trim().isNotEmpty) {
      try {
        final result = await _callGroqText(
          cleanInput,
          availableCategories,
          currentTime,
        );
        if (result.isNotEmpty) {
          dev.log('[LocalAIService] ✅ Groq Text thành công');
          return result;
        }
      } catch (e) {
        dev.log(
          '[LocalAIService] Groq Text thất bại, chuyển Tầng 3 (Gemini)...',
          error: e,
        );
      }
    }

    // ═══════════════════════════════════════════════════════════════════
    // TẦNG 3: Google Gemini 2.5 Flash (Dự phòng cuối cùng)
    // Chỉ gọi khi cả On-Device & Groq đều thất bại
    // ═══════════════════════════════════════════════════════════════════
    if (_geminiApiKey != null && _geminiApiKey!.trim().isNotEmpty) {
      try {
        final result = await _callGeminiFlash(
          cleanInput,
          availableCategories,
          currentTime,
        );
        if (result.isNotEmpty) {
          dev.log('[LocalAIService] ✅ Gemini 2.5 Flash thành công');
          return result;
        }
      } catch (e) {
        dev.log(
          '[LocalAIService] Gemini 2.5 Flash thất bại — trả kết quả On-Device',
          error: e,
        );
      }
    }

    // Nếu tất cả Cloud đều thất bại, trả kết quả On-Device (dù amount = 0)
    return onDeviceResult;
  }

  /// Gọi Groq Cloud Chat Completion với model mới nhất: openai/gpt-oss-20b (fallback llama-3.1-8b-instant)
  Future<List<Map<String, dynamic>>> _callGroqText(
    String text,
    List<String> categories,
    String currentTime,
  ) async {
    return handleDioError(() async {
      final categoriesStr = categories.join(', ');
      final systemPrompt =
          '''
Bạn là trợ lý tài chính thông minh của ứng dụng Pigo. Phân tích câu nói/văn bản tiếng Việt của người dùng thành danh sách các giao dịch tài chính.
Quy tắc bắt buộc:
1. Phân loại type: "outflow" (chi tiêu) hoặc "inflow" (thu nhập).
2. Bóc tách số tiền từ tiếng Việt lóng (k, cành, xị, lít, củ, ngàn, nghìn, triệu, đ, vnd). Vd: 45k -> 45000, 2 củ -> 2000000, 1 lít -> 100000.
3. Khớp categoryName chính xác từ danh sách có sẵn: [$categoriesStr]. Nếu không khớp danh mục nào, để giá trị null.
4. Trường note: ghi chú ngắn gọn, súc tích về món tiền.
5. Trường date: chuỗi ISO-8601 theo mốc thời gian hiện tại: $currentTime (nếu có từ "hôm qua", "hôm kia" hãy trừ lùi ngày tương ứng).
6. ĐẦU RA BẮT BUỘC: Chỉ trả về DUY NHẤT một mảng JSON các object giao dịch. Tuyệt đối không thêm lời giải thích, không bọc markdown ```json.
Ví dụ format: [{"amount": 45000, "type": "outflow", "categoryName": "Ăn uống", "note": "Ăn phở", "date": "$currentTime"}]
''';

      // Ưu tiên model openai/gpt-oss-20b theo catalog hiện tại của Groq, nếu lỗi thì thử llama-3.1-8b-instant
      String modelName = 'openai/gpt-oss-20b';

      try {
        final response = await _dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          data: {
            'model': modelName,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': text},
            ],
            'temperature': 0.1,
            'max_tokens': 1000,
          },
          options: dio.Options(
            headers: {
              'Authorization': 'Bearer ${_groqApiKey!.trim()}',
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final content =
              response.data['choices']?[0]?['message']?['content']
                  ?.toString() ??
              '';
          return _cleanAndParseJson(content);
        }
      } catch (e) {
        dev.log(
          '[LocalAIService] Thử fallback sang llama-3.1-8b-instant...',
          error: e,
        );
        final response = await _dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          data: {
            'model': 'llama-3.1-8b-instant',
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': text},
            ],
            'temperature': 0.1,
            'max_tokens': 1000,
          },
          options: dio.Options(
            headers: {
              'Authorization': 'Bearer ${_groqApiKey!.trim()}',
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final content =
              response.data['choices']?[0]?['message']?['content']
                  ?.toString() ??
              '';
          return _cleanAndParseJson(content);
        }
      }

      throw ServerException('Groq Text response error', 500);
    });
  }

  /// Gọi Gemini 2.5 Flash Chat Completion làm Tầng 2 Cloud Fallback
  Future<List<Map<String, dynamic>>> _callGeminiFlash(
    String text,
    List<String> categories,
    String currentTime,
  ) async {
    return handleDioError(() async {
      final categoriesStr = categories.join(', ');
      final prompt =
          '''
Phân tích văn bản tiếng Việt sau thành danh sách giao dịch tài chính: "$text".
Mốc thời gian hiện tại: $currentTime.
Danh sách danh mục có sẵn: [$categoriesStr].
Quy tắc:
- type: "outflow" (chi tiêu) hoặc "inflow" (thu nhập).
- amount: số tiền dạng số (ví dụ: 45k -> 45000).
- categoryName: khớp từ danh sách trên hoặc null.
- note: nội dung giao dịch.
- date: định dạng ISO-8601.
Chỉ trả về DUY NHẤT mảng JSON hợp lệ dạng: [{"amount": 50000, "type": "outflow", "categoryName": "...", "note": "...", "date": "..."}]
Không giải thích, không bọc markdown.
''';

      final response = await _dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${_geminiApiKey!.trim()}',
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.1,
            'responseMimeType': 'application/json',
          },
        },
        options: dio.Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final candidates = response.data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final textPart =
              candidates[0]['content']?['parts']?[0]?['text']?.toString() ?? '';
          return _cleanAndParseJson(textPart);
        }
      }
      throw ServerException(
        'Gemini 2.5 Flash response error: ${response.statusCode}',
        response.statusCode,
      );
    });
  }

  // ===========================================================================
  // TASK 5-4, 5-6 & 5-7: Phân tích Ảnh Hóa đơn (Lazy Input Vision) — ON-DEVICE FIRST
  // ===========================================================================
  @override
  Future<List<Map<String, dynamic>>> parseReceiptImage({
    required File imageFile,
    required List<String> availableCategories,
    required String currentTime,
  }) async {
    if (!await imageFile.exists()) {
      throw BaseException('Không tìm thấy tệp ảnh hóa đơn.');
    }

    // ═══════════════════════════════════════════════════════════════════
    // TẦNG 1: On-Device — Google ML Kit Text Recognition (OCR Offline)
    // Ưu tiên đọc hóa đơn cục bộ trước, tiết kiệm Token & băng thông
    // ═══════════════════════════════════════════════════════════════════
    dev.log('[LocalAIService] Tầng 1: Google ML Kit OCR (On-Device)');
    List<Map<String, dynamic>> onDeviceResult = [];
    try {
      onDeviceResult = await _parseReceiptWithMLKit(
        imageFile,
        availableCategories,
        currentTime,
      );

      if (_isOnDeviceResultValid(onDeviceResult)) {
        dev.log('[LocalAIService] ✅ ML Kit OCR thành công — totalAmount > 0');
        return onDeviceResult;
      }

      dev.log(
        '[LocalAIService] ⚠️ ML Kit OCR không trích xuất được amount > 0, thử Cloud...',
      );
    } catch (e) {
      dev.log('[LocalAIService] ML Kit OCR lỗi: $e, thử Cloud...');
    }

    // Nếu đang offline, trả kết quả ML Kit ngay (dù totalAmount = 0)
    if (_isOffline) {
      dev.log('[LocalAIService] 📡 Đang offline — trả kết quả ML Kit mặc định');
      return onDeviceResult.isNotEmpty
          ? onDeviceResult
          : [
              {
                'amount': 0.0,
                'type': 'outflow',
                'categoryName': null,
                'note': 'Hóa đơn',
                'date': currentTime,
              },
            ];
    }

    // ═══════════════════════════════════════════════════════════════════
    // TẦNG 2: Groq Vision AI (qwen/qwen3.8-27b)
    // Chỉ gọi khi ML Kit OCR không đọc được & có mạng
    // ═══════════════════════════════════════════════════════════════════
    if (_groqApiKey != null && _groqApiKey!.trim().isNotEmpty) {
      try {
        final result = await _callGroqVision(
          imageFile,
          availableCategories,
          currentTime,
        );
        if (result.isNotEmpty) {
          dev.log('[LocalAIService] ✅ Groq Vision thành công');
          return result;
        }
      } catch (e) {
        dev.log(
          '[LocalAIService] Groq Vision thất bại, chuyển Tầng 3 (Gemini Vision)...',
          error: e,
        );
      }
    }

    // ═══════════════════════════════════════════════════════════════════
    // TẦNG 3: Google Gemini 2.5 Flash Vision (Dự phòng cuối cùng)
    // Chỉ gọi khi cả ML Kit & Groq Vision đều thất bại
    // ═══════════════════════════════════════════════════════════════════
    if (_geminiApiKey != null && _geminiApiKey!.trim().isNotEmpty) {
      try {
        final result = await _callGeminiVision(
          imageFile,
          availableCategories,
          currentTime,
        );
        if (result.isNotEmpty) {
          dev.log('[LocalAIService] ✅ Gemini Vision thành công');
          return result;
        }
      } catch (e) {
        dev.log(
          '[LocalAIService] Gemini Vision thất bại — trả kết quả ML Kit',
          error: e,
        );
      }
    }

    // Nếu tất cả Cloud đều thất bại, trả kết quả ML Kit (dù amount = 0)
    return onDeviceResult.isNotEmpty
        ? onDeviceResult
        : [
            {
              'amount': 0.0,
              'type': 'outflow',
              'categoryName': null,
              'note': 'Hóa đơn',
              'date': currentTime,
            },
          ];
  }

  /// Gọi Groq Cloud Vision với model mới nhất: qwen/qwen3.8-27b
  Future<List<Map<String, dynamic>>> _callGroqVision(
    File imageFile,
    List<String> categories,
    String currentTime,
  ) async {
    return handleDioError(() async {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final categoriesStr = categories.join(', ');

      final promptText =
          '''
Phân tích hình ảnh hóa đơn/biên lai này và trích xuất thông tin giao dịch tài chính.
Mốc thời gian hiện tại: $currentTime.
Danh sách danh mục có sẵn: [$categoriesStr].
Quy tắc:
1. Bóc tách số tiền tổng cộng/thanh toán của hóa đơn.
2. type luôn là "outflow" (chi tiêu).
3. Khớp categoryName chính xác từ danh sách trên (ví dụ: Ăn uống, Mua sắm, Di chuyển). Nếu không rõ, để null.
4. note: Tên cửa hàng / địa điểm hoặc mặt hàng chính trên hóa đơn.
5. date: Ngày in trên hóa đơn nếu đọc được, ngược lại dùng: $currentTime.
6. Chỉ trả về DUY NHẤT một mảng JSON: [{"amount": number, "type": "outflow", "categoryName": string_or_null, "note": string, "date": string}].
Tuyệt đối không giải thích, không kèm markdown.
''';

      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        data: {
          'model': 'qwen/qwen3.8-27b',
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': promptText},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64String'},
                },
              ],
            },
          ],
          'temperature': 0.1,
          'max_tokens': 1000,
        },
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer ${_groqApiKey!.trim()}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final content =
            response.data['choices']?[0]?['message']?['content']?.toString() ??
            '';
        return _cleanAndParseJson(content);
      }
      throw ServerException(
        'Groq Vision response error: ${response.statusCode}',
        response.statusCode,
      );
    });
  }

  /// Gọi Google Gemini 2.5 Flash Vision làm Tầng 2 Cloud Fallback
  Future<List<Map<String, dynamic>>> _callGeminiVision(
    File imageFile,
    List<String> categories,
    String currentTime,
  ) async {
    return handleDioError(() async {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final categoriesStr = categories.join(', ');

      final promptText =
          '''
Đọc hóa đơn này và trích xuất thành mảng JSON giao dịch.
Thời gian: $currentTime.
Danh mục có sẵn: [$categoriesStr].
Format: [{"amount": number, "type": "outflow", "categoryName": "...", "note": "...", "date": "..."}].
Chỉ trả về JSON, không giải thích.
''';

      final response = await _dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${_geminiApiKey!.trim()}',
        data: {
          'contents': [
            {
              'parts': [
                {'text': promptText},
                {
                  'inlineData': {
                    'mimeType': 'image/jpeg',
                    'data': base64String,
                  },
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.1,
            'responseMimeType': 'application/json',
          },
        },
        options: dio.Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final candidates = response.data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final textPart =
              candidates[0]['content']?['parts']?[0]?['text']?.toString() ?? '';
          return _cleanAndParseJson(textPart);
        }
      }
      throw ServerException(
        'Gemini 2.5 Flash Vision response error: ${response.statusCode}',
        response.statusCode,
      );
    });
  }

  // ===========================================================================
  // TASK 5-6: Google ML Kit Offline Text Recognition cho Hóa đơn
  // ===========================================================================
  Future<List<Map<String, dynamic>>> _parseReceiptWithMLKit(
    File imageFile,
    List<String> availableCategories,
    String currentTime,
  ) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      final fullText = recognizedText.text;
      dev.log(
        '[MLKit OCR] Recognized text lines: ${recognizedText.blocks.length}',
      );

      // 1. Trích xuất số tiền tổng cộng bằng Regex bóc tách hóa đơn tiếng Việt
      double totalAmount = 0.0;
      final totalRegex = RegExp(
        r'(?:tổng\s*cộng|tổng\s*tiền|thành\s*tiền|total|thanh\s*toán|tiền\s*mặt|phải\s*trả|cộng\s*tiền\s*hàng|tong\s*cong|thanh\s*toan)\s*[:=]?\s*([0-9\.,]+)',
        caseSensitive: false,
      );

      final match = totalRegex.firstMatch(fullText);
      if (match != null) {
        final rawNum = match.group(1);
        totalAmount = _parseMoneyString(rawNum);
      }

      // Nếu không khớp từ khóa tổng cộng, duyệt tất cả các số tiền lớn nhất trong ảnh
      if (totalAmount <= 0) {
        final anyMoneyRegex = RegExp(
          r'\b(\d{1,3}(?:[\.,]\d{3})*(?:[\.,]\d+)?)\b',
        );
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            for (final m in anyMoneyRegex.allMatches(line.text)) {
              final val = _parseMoneyString(m.group(1));
              if (val > totalAmount && val < 100000000) {
                totalAmount = val;
              }
            }
          }
        }
      }

      // 2. Nhận diện danh mục phù hợp
      String? matchedCat;
      final lowerText = fullText.toLowerCase();
      if (lowerText.contains('cà phê') ||
          lowerText.contains('cafe') ||
          lowerText.contains('nhà hàng') ||
          lowerText.contains('quán ăn') ||
          lowerText.contains('phở') ||
          lowerText.contains('bún') ||
          lowerText.contains('trà sữa') ||
          lowerText.contains('restaurant')) {
        matchedCat = availableCategories.firstWhereOrNull(
          (c) =>
              c.toLowerCase().contains('ăn') ||
              c.toLowerCase().contains('uống'),
        );
      } else if (lowerText.contains('siêu thị') ||
          lowerText.contains('mart') ||
          lowerText.contains('circle k') ||
          lowerText.contains('vinmart') ||
          lowerText.contains('winmart') ||
          lowerText.contains('bách hóa')) {
        matchedCat = availableCategories.firstWhereOrNull(
          (c) =>
              c.toLowerCase().contains('mua') ||
              c.toLowerCase().contains('sắm'),
        );
      } else if (lowerText.contains('xăng') || lowerText.contains('petrol')) {
        matchedCat = availableCategories.firstWhereOrNull(
          (c) =>
              c.toLowerCase().contains('xe') ||
              c.toLowerCase().contains('di chuyển'),
        );
      }

      // Lấy tên file hóa đơn làm note
      final fileName = imageFile.path.split(Platform.pathSeparator).last;

      return [
        {
          'amount': totalAmount,
          'type': 'outflow',
          'categoryName': matchedCat,
          'note': 'Hóa đơn',
          'date': currentTime,
        },
      ];
    } finally {
      await textRecognizer.close();
    }
  }

  /// Chuyển đổi chuỗi số tiền dạng "45,000" hoặc "45.000" thành double
  double _parseMoneyString(String? raw) {
    if (raw == null) return 0.0;
    String clean = raw.replaceAll(' ', '').trim();
    // Chuẩn hóa định dạng tiền tệ VNĐ (dấu chấm phân tách phần nghìn)
    if (clean.contains('.') && clean.contains(',')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (clean.contains('.')) {
      // Ví dụ: 50.000 -> 50000
      clean = clean.replaceAll('.', '');
    } else if (clean.contains(',')) {
      // Ví dụ: 50,000 -> 50000
      clean = clean.replaceAll(',', '');
    }
    return double.tryParse(clean) ?? 0.0;
  }

  // ===========================================================================
  // Helper: Làm sạch chuỗi JSON từ LLM và Parse an toàn
  // ===========================================================================
  List<Map<String, dynamic>> _cleanAndParseJson(String rawText) {
    String clean = rawText.trim();

    // Loại bỏ markdown code blocks ```json ... ``` hoặc ``` ... ```
    if (clean.startsWith('```')) {
      final lines = clean.split('\n');
      if (lines.first.startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.startsWith('```')) {
        lines.removeLast();
      }
      clean = lines.join('\n').trim();
    }

    // Tìm vị trí mở mảng [ hoặc mở object {
    final startBracket = clean.indexOf('[');
    final endBracket = clean.lastIndexOf(']');

    if (startBracket != -1 && endBracket != -1 && endBracket > startBracket) {
      clean = clean.substring(startBracket, endBracket + 1);
    }

    final decoded = jsonDecode(clean);
    if (decoded is List) {
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (decoded is Map) {
      return [Map<String, dynamic>.from(decoded)];
    }

    return [];
  }
}
