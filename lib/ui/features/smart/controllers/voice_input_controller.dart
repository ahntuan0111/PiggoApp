import 'dart:io';
import 'package:appintern/core/enums/voice_input_state.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/domain/services/i_ai_service.dart';
import 'package:appintern/ui/features/transaction/widgets/confirm_multiple_transactions_bottom_sheet.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/ui/widgets/dialogs/permission_dialog.dart';
import 'package:appintern/ui/features/smart/widgets/ai_parse_error_dialog.dart';
import 'package:appintern/ui/widgets/dialogs/category_required_dialog.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/offline_voice_model_manager.dart';

class VoiceInputController extends BaseController
    with BudgetAware, GetSingleTickerProviderStateMixin {
  final IAIService aiService = Get.find<IAIService>();
  final TransactionRepository _transactionRepository =
      Get.find<TransactionRepository>();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  late AnimationController pulseController;
  var currentState = VoiceInputState.idle.obs;
  var rawText = "".obs;
  var isSttInitialized = false.obs;
  var isOfflineMode = false.obs;

  String? _audioPath;
  String _selectedLocaleId = 'vi_VN';

  // ignore: unused_field
  late final OfflineVoiceModelManager _offlineModelManager;

  @override
  void onInit() {
    super.onInit();
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    if (Get.isRegistered<OfflineVoiceModelManager>()) {
      _offlineModelManager = Get.find<OfflineVoiceModelManager>();
    } else {
      _offlineModelManager = Get.put(OfflineVoiceModelManager());
    }

    _initSpeechToText();
  }

  Future<void> _initSpeechToText() async {
    final result = await ErrorHandler.execute(() async {
      final available = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('[VoiceInput] STT status: $status');
          if (status == 'done' || status == 'notListening') {
            if (currentState.value == VoiceInputState.recording &&
                rawText.value.trim().isNotEmpty) {
              currentState.value = VoiceInputState.confirmingText;
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('[VoiceInput] STT error: ${errorNotification.errorMsg}');
        },
      );

      if (available) {
        final locales = await _speechToText.locales();
        final viLocale = locales.firstWhereOrNull(
          (loc) => loc.localeId.toLowerCase().startsWith('vi'),
        );
        if (viLocale != null) {
          _selectedLocaleId = viLocale.localeId;
        }
      }
      return available;
    }, tag: "INIT_STT");

    result.fold(
      (failure) {
        isSttInitialized.value = false;
      },
      (available) {
        isSttInitialized.value = available;
      },
    );
  }

  @override
  void onReady() {
    super.onReady();
    if (budgetService.activeCategories.isEmpty) {
      Get.back();
      if (Get.context != null) {
        showCategoryRequiredDialog(Get.context!);
      }
      return;
    }
    final isNetworkOffline = Get.find<NetworkService>().isOffline.value;
    isOfflineMode.value = isNetworkOffline;

    if (!isNetworkOffline) {
      // [BUG-07] Vô hiệu hóa tác vụ tải ngầm gói Vosk 43MB để tránh lãng phí băng thông & bộ nhớ
      // cho đến khi có engine Vosk offline thực sự được tích hợp vào dự án.
      // _offlineModelManager.downloadOfflineModelIfNeeded();
    } else {
      // Khi offline: Thông báo chế độ ngoại tuyến, không chặn người dùng
      showInfoMessage(
        "Chế độ Ngoại tuyến",
        "Đang nhận diện giọng nói trực tiếp trên thiết bị (không cần kết nối mạng).",
      );
    }
  }

  @override
  void onClose() {
    pulseController.dispose();
    _audioRecorder.dispose();
    _speechToText.stop();
    super.onClose();
  }

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      PermissionDialog.show(
        "Quyền truy cập Micro bị từ chối",
        "Vui lòng vào Cài đặt để cấp quyền truy cập Micro cho ứng dụng để sử dụng tính năng nhận diện giọng nói.",
      );
      return false;
    } else if (!status.isGranted) {
      showErrorMessage(
        "Thiếu quyền truy cập",
        "Vui lòng cấp quyền Micro để sử dụng tính năng này.",
      );
      return false;
    }
    return true;
  }

  Future<void> handlePointerDown() async {
    if (currentState.value != VoiceInputState.idle) return;

    if (await Permission.microphone.isGranted) {
      await _startListeningAndRecording();
    } else {
      final granted = await requestPermission();
      if (granted) {
        await _startListeningAndRecording();
      }
    }
  }

  Future<void> handlePointerUp() async {
    if (currentState.value == VoiceInputState.recording) {
      await stopListeningAndProcess();
    }
  }

  Future<void> _startListeningAndRecording() async {
    rawText.value = "";

    final result = await ErrorHandler.execute(() async {
      // 1. Thử nhận dạng trực tiếp qua SpeechToText (Native OS vi_VN)
      if (isSttInitialized.value) {
        await _speechToText.listen(
          onResult: (result) {
            rawText.value = result.recognizedWords;
          },
          localeId: _selectedLocaleId,
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.confirmation,
            cancelOnError: false,
            partialResults: true,
          ),
        );
      }

      // 2. Dự phòng: Luôn ghi âm file wav qua AudioRecorder
      // để nếu STT Native trên một số dòng máy không trả về text thì gửi lên Groq Whisper
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _audioPath = '${dir.path}/voice_input.wav';

        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        );
        await _audioRecorder.start(config, path: _audioPath!);
      }
    }, tag: "START_LISTENING_RECORDING");

    result.fold(
      (failure) {
        showErrorMessage("Lỗi thu âm", failure.message);
      },
      (_) {
        currentState.value = VoiceInputState.recording;
      },
    );
  }

  Future<void> stopListeningAndProcess() async {
    if (currentState.value != VoiceInputState.recording) return;

    final result = await ErrorHandler.execute(() async {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      return await _audioRecorder.stop();
    }, tag: "STOP_LISTENING_RECORDING");

    result.fold(
      (failure) {
        currentState.value = VoiceInputState.idle;
        showErrorMessage("Lỗi dừng thu âm", failure.message);
      },
      (recordedPath) async {
        if (recordedPath != null) {
          _audioPath = recordedPath;
        }

        // Kiểm tra kết quả bóc tách
        if (rawText.value.trim().isNotEmpty) {
          // Ưu tiên 1 & 2: Đã nhận dạng được chuỗi văn bản từ Native OS / Gói Offline
          currentState.value = VoiceInputState.confirmingText;
        } else if (_audioPath != null && File(_audioPath!).existsSync()) {
          // Ưu tiên 3: Nếu Native STT không trả về text, gọi Groq Whisper API qua file ghi âm
          await _processAudioToText();
        } else {
          currentState.value = VoiceInputState.idle;
          showWarningMessage(
            "Thông báo",
            "Chưa nhận diện được giọng nói. Vui lòng thử lại.",
          );
        }
      },
    );
  }

  Future<void> _processAudioToText() async {
    currentState.value = VoiceInputState.sttProcessing;

    final result = await ErrorHandler.execute(() async {
      return await aiService.convertSpeechToText(_audioPath!);
    }, tag: "STT_VOICE_INPUT");

    result.fold(
      (failure) async {
        currentState.value = VoiceInputState.idle;
        showErrorMessage("Lỗi nhận diện", failure.message);
      },
      (text) async {
        rawText.value = text;
        currentState.value = VoiceInputState.confirmingText;
      },
    );
  }

  Future<void> confirmAndProcessLLM() async {
    if (currentState.value != VoiceInputState.confirmingText) return;
    await _processTextWithLLM(rawText.value);
  }

  void retryVoiceInput() {
    currentState.value = VoiceInputState.idle;
    rawText.value = "";
  }

  Future<void> _processTextWithLLM(String text) async {
    currentState.value = VoiceInputState.aiProcessing;

    final validCategoryNames = budgetService.activeCategoryGroups
        .expand((group) => group.categories)
        .map((budgetCat) => budgetCat.name)
        .toList();
    final currentTime = DateTime.now().toUtc().toIso8601String();

    final result = await ErrorHandler.execute(() async {
      return await aiService.parseTransactionText(
        text: text,
        availableCategories: validCategoryNames,
        currentTime: currentTime,
      );
    }, tag: "PARSE_VOICE_INPUT");

    currentState.value = VoiceInputState.idle; // Reset state

    result.fold(
      (failure) {
        Get.dialog(const AiParseErrorDialog());
      },
      (data) {
        // Mở ConfirmMultipleTransactionsBottomSheet đè lên màn hình hiện tại
        Get.bottomSheet(
          ConfirmMultipleTransactionsBottomSheet(
            aiParsedDataList: data,
            availableCategories: validCategoryNames,
            unallocatedAmount: budgetService.unallocatedAmount.value,
            onConfirmAll: (confirmedDataList) async =>
                await _saveTransaction(confirmedDataList, text),
          ),
          isScrollControlled: true,
        );
      },
    );
  }

  Future<void> _saveTransaction(
    List<Map<String, dynamic>> confirmedDataList,
    String rawInputText,
  ) async {
    showLoading();

    final saveResult = await ErrorHandler.execute(() async {
      for (var confirmedData in confirmedDataList) {
        final catName = confirmedData['categoryName'];
        CategoryModel? category;
        if (catName != null) {
          final budgetCat = budgetService.categories.firstWhereOrNull(
            (c) => c.name == catName,
          );
          if (budgetCat != null) category = budgetCat.categoryModel;
        }

        final type = confirmedData['type'] == 'inflow' ? 'INCOME' : 'EXPENSE';
        final amount = (confirmedData['amount'] as num).toDouble();
        final note = confirmedData['note']?.toString() ?? '';
        final txDate = confirmedData['date'] as DateTime? ?? DateTime.now();

        final tx = TransactionModel(
          id: '',
          categoryId: category?.id ?? '',
          amount: amount,
          type: type,
          transactionDate: txDate,
          status: 'COMPLETED',
          note: note,
        );

        final detail = TransactionDetailModel(
          id: '',
          transactionId: '',
          note: note,
          receiptFileIds: [],
          rawInputText: rawInputText,
          confidenceScore: 0.95,
        );

        if (category == null) {
          await _transactionRepository.createWalletAdjustmentTransaction(
            transaction: tx,
            transactionDetail: detail,
          );
        } else {
          await _transactionRepository.createTransaction(
            transaction: tx,
            transactionDetail: detail,
            currentCategory: category,
          );
        }
      }
    }, tag: "SAVE_MULTIPLE_VOICE_TRANSACTIONS");

    hideLoading();

    saveResult.fold((failure) => showErrorMessage("Lỗi", failure.message), (_) {
      Get.back(); // Chỉ đóng form confirm, giữ nguyên màn hình Voice
      rawText.value = ""; // Xóa text cũ để có thể thu âm tiếp
      showSuccessMessage(
        "Thành công",
        "Đã ghi nhận ${confirmedDataList.length} giao dịch",
      );
    });
  }
}
