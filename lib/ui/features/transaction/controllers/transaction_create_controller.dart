import 'package:appintern/core/utils/currency_formatter.dart';
import 'dart:io';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/data/models/budget_category.dart';
import 'package:appintern/data/models/transfer_log_model.dart';
import 'package:appintern/data/repositories/category_repository.dart';
import 'package:appintern/data/repositories/goal_repository.dart';
import 'package:appintern/data/repositories/transfer_log_repository.dart';
import 'package:appintern/ui/widgets/dialogs/permission_dialog.dart';
import 'package:appintern/ui/features/rollover/widgets/post_adjustment_warning_dialog.dart';
import 'package:appintern/ui/widgets/dialogs/category_required_dialog.dart';
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

class TransactionCreateController extends BaseController
    with BudgetAware {
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
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: const Color(0xFF4CAF50)),
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
    if (amountController.text.trim().isEmpty) {
      amountValue.value = 0.0;
      isValidAmount.value = true;
      return;
    }

    double val = CurrencyFormatter.parse(amountController.text);
    amountValue.value = val;
    isValidAmount.value = true;
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
      // Lấy danh sách category từ budgetService (đã lọc các category bị ẩn, chỉ bao gồm Goal đã hoàn thành)
      final validCategories = budgetService.activeCategoryGroups
          .expand((group) => group.categories)
          .toList();

      categories.value = validCategories;

      if (validCategories.isEmpty) {
        hideLoading();
        Get.back();
        if (Get.context != null) {
          showCategoryRequiredDialog(Get.context!);
        }
        return;
      }

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
          amountController.text = CurrencyFormatter.formatNumberOnly(
            editingTransaction!.amount,
          );
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
      } else if (Get.arguments != null &&
          Get.arguments['prefillCategory'] != null) {
        // Xử lý pre-fill từ Goal
        final matchedCategory = categories.firstWhereOrNull(
          (c) => c.categoryModel.id == Get.arguments['prefillCategory'],
        );
        if (matchedCategory != null) {
          selectedCategory.value = matchedCategory;
        }
        if (Get.arguments['prefillAmount'] != null) {
          amountController.text = CurrencyFormatter.formatNumberOnly(
            Get.arguments['prefillAmount'],
          );
          amountValue.value = (Get.arguments['prefillAmount'] as num)
              .toDouble();
        }
      }
    }, tag: "FETCH_TRANSACTION_CREATE");

    hideLoading();
    result.fold((failure) {
      // Không hiển thị lỗi kỹ thuật ra UI, đặc biệt khi Offline
      AppLogger.error("FETCH_TRANSACTION_CREATE", failure.message);
    }, (_) {});
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
        final ImageSource? source = await Get.bottomSheet<ImageSource>(
          Material(
            color: Get.theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Thêm ảnh giao dịch',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.camera_alt, color: Colors.blue),
                      title: const Text('Chụp từ Máy ảnh'),
                      onTap: () => Get.back(result: ImageSource.camera),
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library, color: Colors.green),
                      title: const Text('Chọn từ Thư viện'),
                      onTap: () => Get.back(result: ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (source != null) {
          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(source: source);
          if (image != null) {
            imagePaths.add(image.path);
          }
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
    double baseSpent = selectedCategory.value!.spent;
    if (isEdit.value &&
        editingTransaction != null &&
        selectedCategory.value!.categoryModel.id ==
            editingTransaction!.categoryId) {
      baseSpent -= editingTransaction!.amount;
    }
    return baseSpent + amountValue.value;
  }

  double get currentRemaining {
    if (selectedCategory.value == null) return 0.0;
    double allocated = selectedCategory.value!.allocated;
    return allocated - currentSpent;
  }

  double get currentProgress {
    if (selectedCategory.value == null) return 0.0;
    double defaultBudget = selectedCategory.value!.allocated;
    if (defaultBudget == 0) return 0.0;

    double ratio = currentSpent / defaultBudget;
    if (ratio > 1.0) ratio = 1.0;
    if (ratio < 0.0) ratio = 0.0;
    return ratio;
  }

  bool get isOverBudget {
    return currentRemaining < 0;
  }

  Future<void> addTransaction({bool closeAfterSave = true}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 150));

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
          _executeUpdateTransaction(closeAfterSave: closeAfterSave);
        } else {
          _executeSaveTransaction(closeAfterSave: closeAfterSave);
        }
      });
    } else {
      if (isEdit.value) {
        _executeUpdateTransaction(closeAfterSave: closeAfterSave);
      } else {
        _executeSaveTransaction(closeAfterSave: closeAfterSave);
      }
    }
  }

  Future<void> _executeSaveTransaction({bool closeAfterSave = true}) async {
    showLoading();

    final result = await ErrorHandler.execute(() async {
      List<String> uploadedFileIds = imagePaths.toList();

      final tx = TransactionModel(
        id: '',
        categoryId: selectedCategory.value!.categoryModel.id,
        amount: amountValue.value,
        type: 'EXPENSE',
        transactionDate: selectedDate.value,
        status: 'COMPLETED',
        note: noteController.text.trim(),
      );

      final detail = TransactionDetailModel(
        id: '',
        transactionId: '',
        note: noteController.text.trim(),
        receiptFileIds: uploadedFileIds,
        rawInputText: '',
        confidenceScore: 1.0,
      );

      await transactionRepository.createTransaction(
        transaction: tx,
        transactionDetail: detail,
        currentCategory: selectedCategory.value!.categoryModel,
      );

      // AUTO-SWEEP LOGIC FOR GOALS
      final budgetService = Get.find<BudgetService>();
      final goal = budgetService.goals.firstWhereOrNull(
        (g) => g.categoryId == tx.categoryId,
      );
      if (goal != null) {
        double savedAmount =
            budgetService.categories
                .firstWhereOrNull((c) => c.categoryModel.id == goal.categoryId)
                ?.remaining ??
            0.0;
        double difference = tx.amount - savedAmount; // spent - saved
        final monthYearStr =
            "${selectedDate.value.month.toString().padLeft(2, '0')}-${selectedDate.value.year}";

        if (difference != 0) {
          double currentBudget =
              budgetService
                  .getBudgetForCategory(goal.categoryId)
                  ?.budgetedAmount ??
              0.0;
          double newBudget = currentBudget + difference;

          final categoryRepo = Get.find<CategoryRepository>();
          final mbTarget = budgetService.getBudgetForCategory(
            goal.categoryId,
          );
          if (mbTarget != null) {
            await categoryRepo.updateMonthlyBudget(mbTarget.id, newBudget);
          } else {
            await categoryRepo.createMonthlyBudget(
              categoryId: goal.categoryId,
              monthYear: monthYearStr,
              budgetedAmount: newBudget,
            );
          }

          final transferRepo = Get.find<TransferLogRepository>();
          await transferRepo.createTransferLog(
            TransferLogModel(
              id: '',
              amount: difference.abs(),
              fromCategoryId: difference > 0
                  ? 'unallocated'
                  : goal.categoryId,
              toCategoryId: difference > 0 ? goal.categoryId : 'unallocated',
              note: 'Auto-sweep chênh lệch mục tiêu',
              createdAt: DateTime.now(),
            ),
          );
        }

        if (goal.status != 'COMPLETED') {
          final updatedGoal = goal.copyWith(status: 'COMPLETED');
          await Get.find<GoalRepository>().updateGoal(updatedGoal);
        }

        if (difference > 0) {
          Future.delayed(
            const Duration(milliseconds: 500),
            () => showSuccessMessage(
              "Cân bằng ngân sách",
              "Đã lấy ${CurrencyFormatter.format(difference)} từ ví chung bù vào mục tiêu.",
            ),
          );
        } else if (difference < 0) {
          Future.delayed(
            const Duration(milliseconds: 500),
            () => showSuccessMessage(
              "Cân bằng ngân sách",
              "Đã hoàn ${CurrencyFormatter.format(-difference)} tiền thừa về ví.",
            ),
          );
        }
      }
    }, tag: "ADD_TRANSACTION");

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Lỗi", "Không thể thêm giao dịch: ${failure.message}");
      },
      (_) async {
        showSuccessMessage("Thành công", "Đã lưu giao dịch");

        if (closeAfterSave) {
          Get.back(result: true);
        } else {
          await _resetFields();
        }
      },
    );
  }

  Future<void> _executeUpdateTransaction({bool closeAfterSave = true}) async {
    if (editingTransaction == null) return;
    showLoading();

    final result = await ErrorHandler.execute(() async {
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

      await transactionRepository.updateTransaction(
        oldTransaction: editingTransaction!,
        newTransaction: newTx,
        newTransactionDetail: newDetail,
        oldCategory: oldCategory,
        newCategory: selectedCategory.value!.categoryModel,
      );
    }, tag: "UPDATE_TRANSACTION");

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage(
          "Lỗi",
          "Không thể cập nhật giao dịch: ${failure.message}",
        );
      },
      (_) async {
        showSuccessMessage("Thành công", "Đã cập nhật giao dịch");

        if (closeAfterSave) {
          Get.back(result: true);
        } else {
          await _resetFields();
        }
      },
    );
  }

  Future<void> _resetFields() async {
    amountController.clear();
    noteController.clear();
    imagePaths.clear();
    // Đặt lại các giá trị obs
    amountValue.value = 0.0;
    isValidAmount.value = true;
    selectedCategory.value = null; // Bỏ chọn danh mục để ép chọn lại

    // Nạp lại data để cập nhật progress cho danh mục
    await budgetService.refreshData();
    final validCategories = budgetService.activeCategoryGroups
        .where((group) => group.typeName != 'Tiết kiệm lâu dài')
        .expand((group) => group.categories)
        .toList();
    categories.value = validCategories;
  }

  String formatCurrency(double amount) {
    return CurrencyFormatter.format(amount);
  }

  @override
  void onClose() {
    amountController.dispose();
    noteController.dispose();
    super.onClose();
  }
}
