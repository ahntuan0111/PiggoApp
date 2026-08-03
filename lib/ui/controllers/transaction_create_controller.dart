import 'dart:convert';
import 'dart:io';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/offline_sync_service.dart';
import 'package:appintern/data/data_sources/local/local_database_service.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/utils/logger.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:appintern/ui/widgets/dialogs/post_adjustment_warning_dialog.dart';
import 'package:appintern/ui/widgets/dialogs/permission_dialog.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class TransactionCreateController extends BaseController with BudgetAware {
  final storage = Get.find<StorageService>();
  final TransactionRepository transactionRepository =
      Get.find<TransactionRepository>();
  final StorageRepository storageRepository = Get.find<StorageRepository>();

  var currentUserId = "".obs;

  // Edit Mode
  var isEdit = false.obs;
  TransactionModel? editingTransaction;
  TransactionDetailModel? editingDetail;
  CategoryModel? oldCategory;

  // Cập nhật giao diện mà không phá vỡ UI
  final selectedWalletName = 'Ngân sách'.obs;

  // Input
  final amountController = TextEditingController();
  final amountValue = 0.0.obs;
  final isValidAmount = true.obs;

  // Category Selection
  // Category Selection
  final categories = <BudgetCategory>[].obs;
  final selectedCategory = Rxn<BudgetCategory>();

  // Date Selection
  final selectedDate = DateTime.now().obs;

  Future<void> pickDate(BuildContext context) async {
    DateTime firstDate;
    DateTime lastDate;

    if (isEdit.value && editingTransaction != null) {
      final txDate = editingTransaction!.transactionDate;
      firstDate = DateTime(txDate.year, txDate.month, 1);
      lastDate = DateTime(txDate.year, txDate.month + 1, 0);
    } else {
      final trackingMonth = budgetService.currentTrackingMonth.value;
      firstDate = DateTime(trackingMonth.year, trackingMonth.month, 1);
      lastDate = DateTime(trackingMonth.year, trackingMonth.month + 1, 0);
    }

    DateTime initialDate = selectedDate.value;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate.value) {
      selectedDate.value = picked;
    }
  }

  void setDate(DateTime date) {
    DateTime firstDate;
    DateTime lastDate;

    if (isEdit.value && editingTransaction != null) {
      final txDate = editingTransaction!.transactionDate;
      firstDate = DateTime(txDate.year, txDate.month, 1);
      lastDate = DateTime(txDate.year, txDate.month + 1, 0);
    } else {
      final trackingMonth = budgetService.currentTrackingMonth.value;
      firstDate = DateTime(trackingMonth.year, trackingMonth.month, 1);
      lastDate = DateTime(trackingMonth.year, trackingMonth.month + 1, 0);
    }

    if (date.isBefore(firstDate) || date.isAfter(lastDate)) {
      showErrorMessage(
        "Ngày không hợp lệ",
        "Chỉ được chọn ngày trong tháng hiện tại.",
      );
      return;
    }

    selectedDate.value = date;
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Note
  final noteController = TextEditingController();

  // Images (Max 3)
  final imagePaths = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = storage.read(AppKeys.userId) ?? "";
    amountController.addListener(_onAmountChanged);
  }

  @override
  void onReady() {
    super.onReady();
    fetchData();
  }

  void _onAmountChanged() {
    String text = amountController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('đ', '')
        .trim();
    if (text.isEmpty) {
      amountValue.value = 0.0;
      isValidAmount.value = true;
    } else {
      double? val = double.tryParse(text);
      if (val != null) {
        amountValue.value = val;
        isValidAmount.value = true;
      } else {
        isValidAmount.value = false;
      }
    }
  }

  Future<void> fetchData() async {
    final userId = currentUserId.value;
    if (userId.isEmpty) return;

    showLoading();
    final result = await ErrorHandler.execute(() async {
      // Đảm bảo budgetService đã load xong data
      if (!budgetService.isDataLoaded.value) {
        await budgetService.refreshData();
      }
      // Lọc ra các categories KHÔNG thuộc nhóm "Tiết kiệm lâu dài" (Goal Savings)
      // Vì Goal Savings có luồng nạp/rút riêng, không thể thêm giao dịch thông thường.
      final validCategories = budgetService.activeCategoryGroups
          .where((group) => group.typeName != 'Tiết kiệm lâu dài')
          .expand((group) => group.categories)
          .toList();

      categories.value = validCategories;

      if (!isEdit.value) {
        final trackingMonth = budgetService.currentTrackingMonth.value;
        final now = DateTime.now();
        if (now.year == trackingMonth.year &&
            now.month == trackingMonth.month) {
          selectedDate.value = now;
        } else {
          selectedDate.value = DateTime(
            trackingMonth.year,
            trackingMonth.month,
            1,
          );
        }
      }

      // Xử lý dữ liệu Chỉnh sửa (Edit Mode) nếu được truyền sang
      if (Get.arguments != null && Get.arguments['isEdit'] == true) {
        isEdit.value = true;
        editingTransaction = Get.arguments['transaction'] as TransactionModel?;
        editingDetail = Get.arguments['detail'] as TransactionDetailModel?;

        if (editingTransaction != null) {
          final formatter = NumberFormat('#,###', 'vi_VN');
          amountController.text = formatter.format(editingTransaction!.amount);
          noteController.text =
              editingDetail?.note ?? editingTransaction!.note ?? '';
          selectedDate.value = editingTransaction!.transactionDate;

          final matchedCategory = categories.firstWhereOrNull(
            (c) => c.categoryModel.id == editingTransaction!.categoryId,
          );
          if (matchedCategory != null) {
            selectedCategory.value = matchedCategory;
            oldCategory = matchedCategory.categoryModel;
          }
        }
      }
    }, tag: "FETCH_TRANSACTION_CREATE");

    hideLoading();
    result.fold(
      (failure) {
        // Không hiển thị lỗi kỹ thuật ra UI, đặc biệt khi Offline
        AppLogger.error("FETCH_TRANSACTION_CREATE", failure.message);
      },
      (_) {},
    );
  }

  Future<void> pickImage() async {
    if (imagePaths.length >= 3) {
      showErrorMessage('Lỗi', 'Chỉ được chọn tối đa 3 ảnh');
      return;
    }

    try {
      PermissionStatus status = PermissionStatus.denied;
      PermissionStatus cameraStatus = PermissionStatus.denied;

      if (Platform.isIOS) {
        status = await Permission.photos.request();
        cameraStatus = await Permission.camera.request();
      } else {
        // Android: Thử request photos (Android 13+) trước, nếu không được thì storage (Android 12-)
        status = await Permission.photos.request();
        if (!status.isGranted) {
          final storageStatus = await Permission.storage.request();
          if (storageStatus.isGranted || storageStatus.isLimited) {
            status = storageStatus;
          }
        }
        cameraStatus = await Permission.camera.request();
      }

      // Xử lý kết quả
      if ((status.isGranted || status.isLimited) && cameraStatus.isGranted) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          imagePaths.add(image.path);
        }
      } else if (status.isPermanentlyDenied ||
          cameraStatus.isPermanentlyDenied) {
        PermissionDialog.show(
          "Quyền truy cập bị từ chối",
          "Vui lòng vào Cài đặt để cấp quyền truy cập Ảnh và Camera cho ứng dụng.",
        );
      } else {
        showErrorMessage(
          'Lỗi',
          'Bạn cần cấp đủ quyền Ảnh và Camera để thêm ảnh giao dịch.',
        );
      }
    } catch (e) {
      showErrorMessage('Lỗi', 'Không thể chọn ảnh: $e');
    }
  }

  void removeImage(int index) {
    if (index >= 0 && index < imagePaths.length) {
      imagePaths.removeAt(index);
    }
  }

  double get currentSpent {
    if (selectedCategory.value == null) return 0.0;
    return selectedCategory.value!.spent + amountValue.value;
  }

  double get currentRemaining {
    if (selectedCategory.value == null) return 0.0;
    return selectedCategory.value!.remaining - amountValue.value;
  }

  double get currentProgress {
    if (selectedCategory.value == null) return 0.0;
    double defaultBudget = selectedCategory.value!.allocated;
    if (defaultBudget == 0) return 0.0;

    double spent = selectedCategory.value!.spent + amountValue.value;
    double ratio = spent / defaultBudget;
    if (ratio > 1.0) ratio = 1.0;
    return ratio;
  }

  bool get isOverBudget {
    return currentRemaining < 0;
  }

  Future<void> addTransaction() async {
    if (!isValidAmount.value || amountValue.value <= 0) {
      showErrorMessage("Lỗi", "Vui lòng nhập số tiền hợp lệ");
      return;
    }
    if (selectedCategory.value == null) {
      showErrorMessage("Lỗi", "Vui lòng chọn danh mục");
      return;
    }
    final selectedDt = selectedDate.value;
    final currentDt = budgetService.currentTrackingMonth.value;

    bool isClosedMonth = false;
    if (selectedDt.year < currentDt.year ||
        (selectedDt.year == currentDt.year &&
            selectedDt.month < currentDt.month)) {
      isClosedMonth = true;
    }

    if (isClosedMonth) {
      PostAdjustmentWarningDialog.show(() {
        if (isEdit.value) {
          _executeUpdateTransaction();
        } else {
          _executeSaveTransaction();
        }
      });
    } else {
      if (isEdit.value) {
        _executeUpdateTransaction();
      } else {
        _executeSaveTransaction();
      }
    }
  }

  Future<void> _executeSaveTransaction() async {
    showLoading();

    final result = await ErrorHandler.execute(() async {
      final networkService = Get.find<NetworkService>();
      final offlineSyncService = Get.find<OfflineSyncService>();
      final localDb = Get.find<LocalDatabaseService>();

      List<String> uploadedFileIds = imagePaths.toList();

      final tempId = 'offline_\${DateTime.now().millisecondsSinceEpoch}';
      final tx = TransactionModel(
        id: networkService.isOffline.value ? tempId : '',
        categoryId: selectedCategory.value!.categoryModel.id,
        amount: amountValue.value,
        type: 'EXPENSE',
        transactionDate: selectedDate.value,
        status: 'COMPLETED',
        note: noteController.text.trim(),
      );

      final detail = TransactionDetailModel(
        id: networkService.isOffline.value ? tempId : '',
        transactionId: networkService.isOffline.value ? tempId : '',
        note: noteController.text.trim(),
        receiptFileIds: uploadedFileIds,
        rawInputText: '',
        confidenceScore: 1.0,
      );

      if (networkService.isOffline.value) {
        final payload = jsonEncode({
          'transaction': tx.toMap(),
          'detail': detail.toMap(),
          'category': selectedCategory.value!.categoryModel.toMap(),
        });
        await offlineSyncService.queueManualTask('CREATE_MANUAL_TX', payload);

        final monthYearStr =
            "\${selectedDate.value.month.toString().padLeft(2, '0')}-\${selectedDate.value.year}";
        await localDb.updateLocalBudgetSpent(
          tx.categoryId,
          monthYearStr,
          tx.amount,
        );
        await localDb.updateLocalSummary(monthYearStr, 0, tx.amount);
      } else {
        await transactionRepository.createTransaction(
          transaction: tx,
          transactionDetail: detail,
          currentCategory: selectedCategory.value!.categoryModel,
        );
      }
    }, tag: "ADD_TRANSACTION");

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Lỗi", "Không thể thêm giao dịch: ${failure.message}");
      },
      (_) {
        if (Get.find<NetworkService>().isOffline.value) {
          Get.find<BudgetService>().refreshData();
        }
        Get.back(result: true);
      },
    );
  }

  Future<void> _executeUpdateTransaction() async {
    if (editingTransaction == null) return;
    showLoading();

    final result = await ErrorHandler.execute(() async {
      final networkService = Get.find<NetworkService>();
      final offlineSyncService = Get.find<OfflineSyncService>();
      final localDb = Get.find<LocalDatabaseService>();

      List<String> uploadedFileIds = imagePaths.toList();

      final newTx = TransactionModel(
        id: editingTransaction!.id,
        categoryId: selectedCategory.value!.categoryModel.id,
        amount: amountValue.value,
        type: 'EXPENSE',
        transactionDate: selectedDate.value,
        status: editingTransaction!.status,
        note: noteController.text.trim(),
      );

      final newDetail = TransactionDetailModel(
        id: editingDetail?.id ?? '',
        transactionId: editingTransaction!.id,
        note: noteController.text.trim(),
        receiptFileIds: uploadedFileIds.isNotEmpty
            ? uploadedFileIds
            : (editingDetail?.receiptFileIds ?? const []),
        rawInputText: editingDetail?.rawInputText ?? '',
        confidenceScore: editingDetail?.confidenceScore ?? 1.0,
      );

      if (networkService.isOffline.value) {
        final payload = jsonEncode({
          'transaction': newTx.toMap(),
          'detail': newDetail.toMap(),
          'oldCategory': oldCategory?.toMap(),
          'newCategory': selectedCategory.value!.categoryModel.toMap(),
        });
        // Sửa từ oldCategory thành oldTransactionModel nếu cần, nhưng SyncEngine đợi oldCategory
        // Wait, _transactionRepo.updateTransaction requires oldTransaction. SyncEngine currently builds it from payload?
        // Wait! SyncEngine's UPDATE_MANUAL_TX: `await _transactionRepo.updateTransaction(transaction: tx, transactionDetail: txDetail, oldCategory: oldCategory, newCategory: newCategory);`
        // However, TransactionRepository.updateTransaction requires `oldTransaction`, not just categories!
        // Let's pass `oldTransaction` in payload!

        final finalPayload = jsonEncode({
          'transaction': newTx.toMap(),
          'detail': newDetail.toMap(),
          'oldCategory': oldCategory?.toMap(),
          'newCategory': selectedCategory.value!.categoryModel.toMap(),
          'oldTransaction': editingTransaction!.toMap(),
        });
        await offlineSyncService.queueManualTask(
          'UPDATE_MANUAL_TX',
          finalPayload,
        );

        final oldMonthYear =
            "\${editingTransaction!.transactionDate.month.toString().padLeft(2, '0')}-\${editingTransaction!.transactionDate.year}";
        final newMonthYear =
            "\${selectedDate.value.month.toString().padLeft(2, '0')}-\${selectedDate.value.year}";

        if (editingTransaction!.categoryId == newTx.categoryId &&
            oldMonthYear == newMonthYear) {
          double diff = newTx.amount - editingTransaction!.amount;
          await localDb.updateLocalBudgetSpent(
            newTx.categoryId,
            newMonthYear,
            diff,
          );
          await localDb.updateLocalSummary(newMonthYear, 0, diff);
        } else {
          await localDb.updateLocalBudgetSpent(
            editingTransaction!.categoryId,
            oldMonthYear,
            -editingTransaction!.amount,
          );
          await localDb.updateLocalSummary(
            oldMonthYear,
            0,
            -editingTransaction!.amount,
          );

          await localDb.updateLocalBudgetSpent(
            newTx.categoryId,
            newMonthYear,
            newTx.amount,
          );
          await localDb.updateLocalSummary(newMonthYear, 0, newTx.amount);
        }
      } else {
        await transactionRepository.updateTransaction(
          oldTransaction: editingTransaction!,
          newTransaction: newTx,
          newTransactionDetail: newDetail,
          oldCategory: oldCategory,
          newCategory: selectedCategory.value!.categoryModel,
        );
      }
    }, tag: "UPDATE_TRANSACTION");

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage(
          "Lỗi",
          "Không thể cập nhật giao dịch: ${failure.message}",
        );
      },
      (_) {
        Get.back(result: true);
      },
    );
  }

  String formatCurrency(double amount) {
    String numStr = amount.toStringAsFixed(0);
    final formatted = numStr.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '${formatted}đ';
  }

  @override
  void onClose() {
    amountController.dispose();
    noteController.dispose();
    super.onClose();
  }
}
