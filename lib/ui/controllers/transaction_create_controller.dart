import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/wallet_model.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:appintern/domain/repositories/storage_repository.dart';
import 'package:appintern/ui/widgets/dialogs/post_adjustment_warning_dialog.dart';
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
  WalletModel? oldWallet;


  // Input
  final amountController = TextEditingController();
  final amountValue = 0.0.obs;
  final isValidAmount = true.obs;

  // Wallet Selection
  final wallets = <WalletModel>[].obs;
  final selectedWallet = Rxn<WalletModel>();

  // Category Selection
  final categories = <CategoryModel>[].obs;
  final selectedCategory = Rxn<CategoryModel>();

  // Date Selection
  final selectedDate = DateTime.now().obs;

  Future<void> pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.value,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
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

      wallets.value = budgetService.wallets;
      if (wallets.isNotEmpty) {
        selectedWallet.value = wallets.first;
      }

      // Lọc ra các categories KHÔNG thuộc nhóm "Tiết kiệm lâu dài" (Goal Savings)
      // Vì Goal Savings có luồng nạp/rút riêng, không thể thêm giao dịch thông thường.
      final validCategories = budgetService.categoryGroups
          .where((group) => group.typeName != 'Tiết kiệm lâu dài')
          .expand((group) => group.categories)
          .map((budgetCat) => budgetCat.categoryModel)
          .toList();

      categories.value = validCategories;

      // Xử lý dữ liệu Chỉnh sửa (Edit Mode) nếu được truyền sang
      if (Get.arguments != null && Get.arguments['isEdit'] == true) {
        isEdit.value = true;
        editingTransaction = Get.arguments['transaction'] as TransactionModel?;
        editingDetail = Get.arguments['detail'] as TransactionDetailModel?;

        if (editingTransaction != null) {
          final formatter = NumberFormat('#,###', 'vi_VN');
          amountController.text = formatter.format(editingTransaction!.amount);
          noteController.text = editingDetail?.note ?? editingTransaction!.note ?? '';
          selectedDate.value = editingTransaction!.transactionDate;

          final matchedWallet = wallets.firstWhereOrNull((w) => w.id == editingTransaction!.walletId);
          if (matchedWallet != null) {
            selectedWallet.value = matchedWallet;
            oldWallet = matchedWallet;
          }

          final matchedCategory = categories.firstWhereOrNull((c) => c.id == editingTransaction!.categoryId);
          if (matchedCategory != null) {
            selectedCategory.value = matchedCategory;
            oldCategory = matchedCategory;
          }
        }
      }
    }, tag: "FETCH_TRANSACTION_CREATE");

    hideLoading();
    result.fold(
      (failure) =>
          showErrorMessage("Lỗi", "Không thể tải dữ liệu: ${failure.message}"),
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
      } else if (status.isPermanentlyDenied || cameraStatus.isPermanentlyDenied) {
        _showPermissionDialog("Quyền truy cập bị từ chối", "Vui lòng vào Cài đặt để cấp quyền truy cập Ảnh và Camera cho ứng dụng.");
      } else {
        showErrorMessage('Lỗi', 'Bạn cần cấp đủ quyền Ảnh và Camera để thêm ảnh giao dịch.');
      }
    } catch (e) {
      showErrorMessage('Lỗi', 'Không thể chọn ảnh: $e');
    }
  }

  void _showPermissionDialog(String title, String message) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: const Text("Cài đặt", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
    double defaultBudget = selectedCategory.value!.defaultBudget;
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
      Get.snackbar(
        "Lỗi",
        "Vui lòng nhập số tiền hợp lệ",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (selectedCategory.value == null) {
      Get.snackbar(
        "Lỗi",
        "Vui lòng chọn danh mục",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (selectedWallet.value == null) {
      Get.snackbar(
        "Lỗi",
        "Vui lòng chọn ví",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    // if (noteController.text.trim().isEmpty) {
    //   Get.snackbar("Lỗi", "Vui lòng nhập ghi chú cho giao dịch", snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    //   return;
    // }

    final selectedDt = selectedDate.value;
    final currentDt = budgetService.currentTrackingMonth.value;
    
    bool isClosedMonth = false;
    if (selectedDt.year < currentDt.year || 
       (selectedDt.year == currentDt.year && selectedDt.month < currentDt.month)) {
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
      // 1. Upload ảnh (nếu có)
      List<String> uploadedFileIds = [];
      for (String path in imagePaths) {
        String fileId = await storageRepository.uploadReceiptImage(File(path));
        uploadedFileIds.add(fileId);
      }

      // 2. Chuẩn bị dữ liệu
      final tx = TransactionModel(
        id: '', // Sẽ được tự gen ở repo
        walletId: selectedWallet.value!.id,
        categoryId: selectedCategory.value!.id,
        amount: amountValue.value,
        type: 'EXPENSE',
        transactionDate: selectedDate.value,
        status: 'COMPLETED',
        note: noteController.text.trim(), // Thêm trường note (Denormalized)
      );

      final detail = TransactionDetailModel(
        id: '',
        transactionId: '', // Repo sẽ gắn ID thực tế vào
        note: noteController.text.trim(),
        receiptFileIds: uploadedFileIds,
        rawInputText: '',
        confidenceScore: 1.0,
      );

      // 3. Gọi repository để lưu
      await transactionRepository.createTransaction(
        transaction: tx,
        transactionDetail: detail,
        currentWallet: selectedWallet.value!,
        currentCategory: selectedCategory.value!,
      );
    }, tag: "ADD_TRANSACTION");

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Lỗi", "Không thể thêm giao dịch: ${failure.message}");
      },
      (_) {
        Get.back(result: true); // Trả về true báo hiệu đã tạo thành công
        Get.snackbar(
          "Thành công",
          "Đã thêm giao dịch",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      },
    );
  }

  Future<void> _executeUpdateTransaction() async {
    if (editingTransaction == null) return;
    showLoading();

    final result = await ErrorHandler.execute(() async {
      // 1. Upload ảnh mới (nếu có)
      List<String> uploadedFileIds = [];
      for (String path in imagePaths) {
        if (!path.startsWith('http')) {
          String fileId = await storageRepository.uploadReceiptImage(File(path));
          uploadedFileIds.add(fileId);
        }
      }

      final newTx = TransactionModel(
        id: editingTransaction!.id,
        walletId: selectedWallet.value!.id,
        categoryId: selectedCategory.value!.id,
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
        receiptFileIds: uploadedFileIds.isNotEmpty ? uploadedFileIds : (editingDetail?.receiptFileIds ?? const []),
        rawInputText: editingDetail?.rawInputText ?? '',
        confidenceScore: editingDetail?.confidenceScore ?? 1.0,
      );

      await transactionRepository.updateTransaction(
        oldTransaction: editingTransaction!,
        newTransaction: newTx,
        newTransactionDetail: newDetail,
        oldWallet: oldWallet ?? selectedWallet.value!,
        newWallet: selectedWallet.value!,
        oldCategory: oldCategory,
        newCategory: selectedCategory.value!,
      );
    }, tag: "UPDATE_TRANSACTION");

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Lỗi", "Không thể cập nhật giao dịch: ${failure.message}");
      },
      (_) {
        Get.back(result: true);
        showSuccessMessage("Thành công", "Đã cập nhật giao dịch thành công");
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
