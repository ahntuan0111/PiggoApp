import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:record/record.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/domain/services/i_ai_service.dart';
import 'package:appintern/ui/widgets/bottom_sheet/confirm_multiple_transactions_bottom_sheet.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';

enum VoiceInputState { idle, recording, sttProcessing, aiProcessing }

class VoiceInputController extends BaseController
    with BudgetAware, GetSingleTickerProviderStateMixin {
  final IAIService aiService = Get.find<IAIService>();
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

    // Yêu cầu quyền ngay khi mở màn hình nhưng không tự động thu âm
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestPermission();
    });
  }

  @override
  void onClose() {
    pulseController.dispose();
    _audioRecorder.dispose();
    super.onClose();
  }

  Future<void> requestPermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      showErrorMessage(
        "Thiếu quyền truy cập",
        "Vui lòng cấp quyền Micro để sử dụng tính năng này.",
      );
    }
  }

  Future<void> handlePointerDown() async {
    if (await Permission.microphone.isGranted) {
      await _startRecording();
    } else {
      await requestPermission();
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
          await _processAudioToText();
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
      (failure) {
        currentState.value = VoiceInputState.idle;
        showErrorMessage("Lỗi nhận diện", failure.message);
      },
      (text) async {
        rawText.value = text;
        await _processTextWithLLM(text);
      },
    );
  }

  Future<void> _processTextWithLLM(String text) async {
    currentState.value = VoiceInputState.aiProcessing;

    final validCategoryNames = budgetService.categoryGroups
        .where((group) => group.typeName != 'Tiết kiệm lâu dài')
        .expand((group) => group.categories)
        .map((budgetCat) => budgetCat.name)
        .toList();
    final currentTime = DateTime.now().toIso8601String();

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
        Get.dialog(
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text("Không thể phân tích", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              "Giọng nói có thể không rõ ràng, chứa từ ngữ không phù hợp hoặc kết nối mạng bị gián đoạn. Vui lòng thử lại với câu khác.",
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text("Đã hiểu", style: TextStyle(color: Color(0xFFEBC14F), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      (data) {
        // Mở ConfirmMultipleTransactionsBottomSheet đè lên màn hình hiện tại
        Get.bottomSheet(
          ConfirmMultipleTransactionsBottomSheet(
            aiParsedDataList: data,
            availableCategories: validCategoryNames,
            unallocatedAmount: budgetService.unallocatedAmount.value,
            onConfirmAll: (confirmedDataList) => _saveTransaction(confirmedDataList, text),
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
      if (budgetService.wallets.isEmpty) throw Exception("Bạn chưa có ví nào.");
      final wallet = budgetService.wallets.first;

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

        final tx = TransactionModel(
          id: '',
          walletId: wallet.id,
          categoryId: category?.id ?? '',
          amount: amount,
          type: type,
          transactionDate: DateTime.now(),
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
            currentWallet: wallet,
          );
        } else {
          await _transactionRepository.createTransaction(
            transaction: tx,
            transactionDetail: detail,
            currentWallet: wallet,
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
