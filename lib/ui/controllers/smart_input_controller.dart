import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/domain/services/i_ai_service.dart';
import 'package:appintern/ui/widgets/bottom_sheet/confirm_multiple_transactions_bottom_sheet.dart';
import 'package:appintern/ui/widgets/dialogs/confirm_dialog_widget.dart';
import 'package:appintern/ui/widgets/dialogs/loading_dialog_widget.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:path_provider/path_provider.dart';

class SmartInputController extends BaseController with BudgetAware {
  final IAIService aiService = Get.find<IAIService>();
  final OfflineSyncService offlineSyncService = Get.find<OfflineSyncService>();
  final StorageRepository storageRepository = Get.find<StorageRepository>();
  final TransactionRepository transactionRepository =
      Get.find<TransactionRepository>();

  final textController = TextEditingController();
  final isProcessing = false.obs;

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  /// Lấy danh sách tên danh mục hợp lệ (loại trừ nhóm Tiết kiệm lâu dài)
  List<String> get _validCategoryNames {
    return budgetService.categoryGroups
        .where((group) => group.typeName != 'Tiết kiệm lâu dài')
        .expand((group) => group.categories)
        .map((budgetCat) => budgetCat.name)
        .toList();
  }

  /// Xử lý gửi văn bản tự nhiên
  Future<void> submitTextInput() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    final handled = await offlineSyncService.handleOfflineAction(
      'TEXT',
      text,
      successMessage: 'Đoạn chat đã được đưa vào hàng chờ đồng bộ',
      isFile: false,
    );
    
    if (handled) {
      textController.clear();
      return;
    }

    isProcessing.value = true;

    // Hiển thị Dialog Loading chặn người dùng thao tác bừa
    Get.dialog(
      const LoadingDialogWidget(
        message: "AI đang phân tích văn bản...",
        subMessage: "Đang nhận diện số tiền và danh mục",
      ),
      barrierDismissible: false,
    );

    final currentTime = DateTime.now().toIso8601String();

    final result = await ErrorHandler.execute(() async {
      return await aiService.parseTransactionText(
        text: text,
        availableCategories: _validCategoryNames,
        currentTime: currentTime,
      );
    }, tag: "PARSE_SMART_INPUT");

    isProcessing.value = false;

    // Tắt Loading Dialog
    if (Get.isDialogOpen == true) Get.back();

    result.fold(
      (failure) {
        Get.dialog(
          ConfirmDialogWidget(
            title: "Không thể phân tích",
            content:
                "Nội dung bạn nhập có thể không rõ ràng, chứa từ ngữ không phù hợp hoặc kết nối mạng bị gián đoạn. Vui lòng thử lại.",
            cancelText: "Đóng",
            confirmText: "Thử lại",
            onConfirm: () => Get.back(),
          ),
        );
      },
      (data) {
        _showConfirmationBottomSheet(data: data, rawText: text);
      },
    );
  }

  /// Trình chọn ảnh/chụp ảnh hóa đơn từ Camera hoặc Gallery
  Future<void> pickAndProcessReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        await submitImageInput(imageFile);
      }
    } catch (e) {
      showErrorMessage(
        "Lỗi chọn ảnh",
        "Không thể mở camera hoặc thư viện ảnh: $e",
      );
    }
  }

  /// Xử lý phân tích ảnh hóa đơn qua AI (Lazy Input Vision)
  Future<void> submitImageInput(File imageFile) async {
    final handled = await offlineSyncService.handleOfflineAction(
      'IMAGE',
      imageFile.path,
      successMessage: 'Ảnh hóa đơn đã được đưa vào hàng chờ đồng bộ',
      isFile: true,
    );
    
    if (handled) return;

    isProcessing.value = true;

    // Hiển thị Dialog Loading chặn người dùng thao tác khi đang bóc tách ảnh
    Get.dialog(
      const LoadingDialogWidget(
        message: "AI đang bóc tách hóa đơn...",
        subMessage: "Đang đọc số tiền & danh mục từ hình ảnh",
      ),
      barrierDismissible: false,
    );

    final currentTime = DateTime.now().toIso8601String();

    final result = await ErrorHandler.execute(() async {
      return await aiService.parseReceiptImage(
        imageFile: imageFile,
        availableCategories: _validCategoryNames,
        currentTime: currentTime,
      );
    }, tag: "PARSE_RECEIPT_IMAGE");

    isProcessing.value = false;

    // Tắt Loading Dialog
    if (Get.isDialogOpen == true) Get.back();

    result.fold(
      (failure) {
        showErrorMessage("Lỗi bóc tách hóa đơn", failure.message);
      },
      (data) {
        _showConfirmationBottomSheet(
          data: data,
          receiptImage: imageFile,
          rawText: '[Ảnh hóa đơn]',
        );
      },
    );
  }

  /// Hiển thị BottomSheet xác nhận giao dịch (Reused UI Helper)
  void _showConfirmationBottomSheet({
    required List<Map<String, dynamic>> data,
    File? receiptImage,
    String rawText = '',
  }) {
    Get.bottomSheet(
      ConfirmMultipleTransactionsBottomSheet(
        aiParsedDataList: data,
        availableCategories: _validCategoryNames,
        unallocatedAmount: budgetService.unallocatedAmount.value,
        receiptImage: receiptImage,
        onConfirmAll: (confirmedDataList) => saveTransactions(
          confirmedDataList,
          rawText: rawText,
          receiptImage: receiptImage,
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// Lưu tập hợp các giao dịch đã được xác nhận vào Database
  Future<void> saveTransactions(
    List<Map<String, dynamic>> confirmedDataList, {
    String rawText = '',
    File? receiptImage,
  }) async {
    showLoading();

    final saveResult = await ErrorHandler.execute(() async {
      // 1. Upload ảnh hóa đơn lên Appwrite Storage Bucket nếu có
      List<String> receiptFileIds = [];
      if (receiptImage != null && await receiptImage.exists()) {
        final uploadedFileId = await storageRepository.uploadReceiptImage(
          receiptImage,
        );
        if (uploadedFileId.isNotEmpty) {
          receiptFileIds.add(uploadedFileId);
        }
      }

      for (var confirmedData in confirmedDataList) {
        final catName = confirmedData['categoryName'];
        CategoryModel? category;
        if (catName != null) {
          final budgetCat = budgetService.categories.firstWhereOrNull(
            (c) => c.name == catName,
          );
          if (budgetCat != null) {
            category = budgetCat.categoryModel;
          }
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
          receiptFileIds: receiptFileIds,
          rawInputText: rawText,
          confidenceScore: 0.90,
        );

        if (category == null) {
          await transactionRepository.createWalletAdjustmentTransaction(
            transaction: tx,
            transactionDetail: detail,
          );
        } else {
          await transactionRepository.createTransaction(
            transaction: tx,
            transactionDetail: detail,
            currentCategory: category,
          );
        }
      }
    }, tag: "SAVE_SMART_TRANSACTIONS");

    hideLoading();

    saveResult.fold(
      (failure) => showErrorMessage(
        "Lỗi",
        "Không thể lưu giao dịch: ${failure.message}",
      ),
      (_) {
        Get.back(); // Đóng Bottom Sheet
        textController.clear();
        Get.snackbar(
          "Thành công",
          "Đã ghi nhận ${confirmedDataList.length} giao dịch",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      },
    );
  }
}
