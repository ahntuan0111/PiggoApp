import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/domain/repositories/wallet_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/wallet_model.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:appintern/domain/repositories/storage_repository.dart';

class TransactionCreateController extends BaseController with BudgetAware {
  final storage = Get.find<StorageService>();
  final TransactionRepository transactionRepository =
      Get.find<TransactionRepository>();
  final StorageRepository storageRepository = Get.find<StorageRepository>();

  var currentUserId = "".obs;

  // Tabs (0: CHI PHÍ, 1: THU NHẬP)
  final selectedTab = 0.obs;

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
      firstDate: DateTime(2000),
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
      // 1. Kiểm tra trạng thái quyền
      var status = await Permission.photos.status;

      // 2. Nếu chưa cấp quyền, tiến hành xin quyền
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }

      // 3. Xử lý kết quả
      if (status.isGranted || status.isLimited) {
        // Nếu người dùng đồng ý -> mở thư viện ảnh
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          imagePaths.add(image.path);
        }
      } else if (status.isPermanentlyDenied) {
        // Nếu người dùng từ chối vĩnh viễn -> yêu cầu vào Cài đặt
        showErrorMessage(
          'Quyền bị từ chối',
          'Vui lòng vào Cài đặt để cấp quyền truy cập Ảnh cho ứng dụng.',
        );
        await openAppSettings();
      } else {
        // Nếu người dùng bấm Từ chối (lần đầu)
        showErrorMessage('Lỗi', 'Bạn cần cấp quyền để thêm ảnh giao dịch.');
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
    double spent = selectedCategory.value!.spent;
    if (selectedTab.value == 0) {
      spent += amountValue.value;
    } else {
      spent -= amountValue.value;
      if (spent < 0) spent = 0;
    }
    return spent;
  }

  double get currentRemaining {
    if (selectedCategory.value == null) return 0.0;
    double baseRemaining = selectedCategory.value!.remaining;
    if (selectedTab.value == 0) {
      return baseRemaining - amountValue.value;
    }
    return baseRemaining + amountValue.value;
  }

  double get currentProgress {
    if (selectedCategory.value == null) return 0.0;
    double defaultBudget = selectedCategory.value!.defaultBudget;
    if (defaultBudget == 0) return 0.0;

    double spent = selectedCategory.value!.spent;
    if (selectedTab.value == 0) {
      spent += amountValue.value;
    } else {
      spent -= amountValue.value;
      if (spent < 0) spent = 0;
    }

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
        type: selectedTab.value == 0 ? 'EXPENSE' : 'INCOME',
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

  String formatCurrency(double amount) {
    String numStr = amount.toStringAsFixed(0);
    return numStr.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        ) +
        'đ';
  }

  @override
  void onClose() {
    amountController.dispose();
    noteController.dispose();
    super.onClose();
  }
}
