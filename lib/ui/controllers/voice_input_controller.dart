import 'dart:io';
import 'package:appintern/core/enums/voice_input_state.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:record/record.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/domain/services/i_ai_service.dart';
import 'package:appintern/ui/widgets/bottom_sheet/confirm_multiple_transactions_bottom_sheet.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/ui/widgets/dialogs/permission_dialog.dart';
import 'package:appintern/ui/widgets/dialogs/ai_parse_error_dialog.dart';

class VoiceInputController extends BaseController
    with BudgetAware, GetSingleTickerProviderStateMixin {
  final IAIService aiService = Get.find<IAIService>();
  final OfflineSyncService offlineSyncService = Get.find<OfflineSyncService>();
  final TransactionRepository _transactionRepository =
      Get.find<TransactionRepository>();
  final AudioRecorder _audioRecorder = AudioRecorder();

  late AnimationController pulseController;
  var currentState = VoiceInputState.idle.obs;
  var rawText = "".obs;

  String? _audioPath;

  @override
  void onInit() {
    super.onInit();
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void onClose() {
    pulseController.dispose();
    _audioRecorder.dispose();
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
      await _startRecording();
    } else {
      final granted = await requestPermission();
      if (granted) {
        await _startRecording();
      }
    }
  }

  Future<void> handlePointerUp() async {
    if (currentState.value == VoiceInputState.recording) {
      await stopRecordingAndProcess();
    }
  }

  Future<void> _startRecording() async {
    final result = await ErrorHandler.execute(() async {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _audioPath = '${dir.path}/voice_input.wav';

        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000, // PhoWhisper/Whisper tối ưu nhất ở 16kHz
          numChannels: 1, // Âm thanh đơn kênh (Mono) là đủ cho AI
        );

        await _audioRecorder.start(config, path: _audioPath!);
      } else {
        throw Exception("Chưa được cấp quyền Micro.");
      }
    }, tag: "START_RECORDING");

    result.fold((failure) => showErrorMessage("Lỗi ghi âm", failure.message), (
      _,
    ) {
      currentState.value = VoiceInputState.recording;
    });
  }

  Future<void> stopRecordingAndProcess() async {
    if (currentState.value != VoiceInputState.recording) return;

    final result = await ErrorHandler.execute(() async {
      return await _audioRecorder.stop();
    }, tag: "STOP_RECORDING");

    result.fold(
      (failure) {
        currentState.value = VoiceInputState.idle;
        showErrorMessage(
          "Lỗi",
          "Không thể lưu file âm thanh: ${failure.message}",
        );
      },
      (path) async {
        if (path != null) {
          _audioPath = path;

          final handled = await offlineSyncService.handleOfflineAction(
            'VOICE',
            path,
            successMessage: 'Giọng nói đã được đưa vào hàng chờ đồng bộ',
            isFile: true,
            showSnackbar: false,
          );

          if (handled) {
            currentState.value = VoiceInputState.idle;
            Get.back(); // Đóng bottom sheet
            
            // Hiển thị thông báo sau khi bottom sheet đóng
            Future.delayed(const Duration(milliseconds: 300), () {
              showSuccessMessage("Ngoại tuyến", "Giọng nói đã được đưa vào hàng chờ đồng bộ");
            });
          } else {
            await _processAudioToText();
          }
        } else {
          currentState.value = VoiceInputState.idle;
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
        if (failure.message.contains("Không thể kết nối đến máy chủ AI") ||
            failure.message.contains("Timeout")) {
          // Gợi ý cho người dùng đưa vào hàng đợi
          final handled = await offlineSyncService.forceQueueOfflineAction(
            'VOICE',
            _audioPath!,
            successMessage: 'Máy chủ bận. Giọng nói đã đưa vào chờ xử lý ngầm.',
            isFile: true,
            showSnackbar: true,
          );
          if (handled) {
            Get.back(); // close bottom sheet
          }
        } else {
          showErrorMessage("Lỗi nhận diện", failure.message);
        }
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
