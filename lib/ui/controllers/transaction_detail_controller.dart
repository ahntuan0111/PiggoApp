import 'dart:typed_data';
import 'package:appintern/core/utils/logger.dart';
import 'package:appintern/data/repositories/storage_repository.dart';
import 'package:get/get.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:collection/collection.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/ui/widgets/dialogs/confirm_dialog_widget.dart';

import 'package:appintern/core/routes/app_routes.dart';

class TransactionDetailController extends BaseController with BudgetAware {
  final TransactionRepository _transactionRepository =
      Get.find<TransactionRepository>();
  final StorageRepository _storageRepo = Get.find<StorageRepository>();

  late Rx<TransactionModel> rxTransaction;
  TransactionModel get transaction => rxTransaction.value;

  var detail = Rxn<TransactionDetailModel>();
  var category = Rxn<CategoryModel>();
  final selectedWalletName = 'Ngân sách'.obs;

  bool get isSystemRollover => transaction.categoryId == 'SYSTEM_ROLLOVER';

  var imageBytes = <String, Uint8List>{}.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments['transaction'] != null) {
      rxTransaction = (Get.arguments['transaction'] as TransactionModel).obs;
      _loadData();
    } else {
      Get.back();
    }
  }

  Future<void> _loadData() async {
    showLoading();

    final result = await ErrorHandler.execute(() async {
      await budgetService.refreshData();
      final updatedTx = await _transactionRepository.getTransactionById(
        transaction.id,
      );
      final detailData = await _transactionRepository.getTransactionDetail(
        transaction.id,
      );
      return {'tx': updatedTx, 'detail': detailData};
    }, tag: "GET_TRANSACTION_DETAIL");

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Lỗi", "Không thể tải chi tiết: ${failure.message}");
      },
      (data) async {
        final updatedTx = data['tx'] as TransactionModel?;
        if (updatedTx != null) {
          rxTransaction.value = updatedTx;
        }

        final dataDetail = data['detail'] as TransactionDetailModel?;
        detail.value = dataDetail;

        if (transaction.categoryId.isNotEmpty) {
          category.value = budgetService.categories
              .map((c) => c.categoryModel)
              .firstWhereOrNull((c) => c.id == transaction.categoryId);
        } else {
          category.value = null;
        }

        imageBytes.clear();
        if (dataDetail != null && dataDetail.receiptFileIds.isNotEmpty) {
          _loadImages(dataDetail.receiptFileIds);
        }
      },
    );
  }

  Future<void> _loadImages(List<String> fileIds) async {
    for (String fileId in fileIds) {
      final result = await ErrorHandler.execute(() async {
        return await _storageRepo.getFileView(fileId);
      }, tag: "LOAD_RECEIPT_IMAGE");

      result.fold(
        (failure) {
          // Chỉ log lỗi, không báo lên UI làm phiền user
          AppLogger.error(
            "LOAD_RECEIPT_IMAGE",
            "Lỗi tải ảnh $fileId: ${failure.message}",
          );
        },
        (bytes) {
          imageBytes[fileId] = Uint8List.fromList(bytes);
        },
      );
    }
  }

  void onDeleteTransaction() {
    // 1. Dry run
    double futureUnallocated = budgetService.unallocatedAmount.value;

    if (transaction.type == 'INCOME') {
      futureUnallocated -= transaction.amount;
    }

    // 2. Dialog if negative
    if (futureUnallocated < 0) {
      Get.dialog(
        ConfirmDialogWidget(
          title: "Cảnh báo nghiêm trọng",
          content:
              "Việc xóa khoản giao dịch này sẽ làm "
              "Tiền Chưa Phân Bổ"
              " của bạn bị ÂM. Bạn có chắc chắn muốn xóa không?",
          confirmText: "Vẫn Xóa",
          cancelText: "Hủy bỏ",
          onConfirm: () {
            Get.back();
            _executeDelete();
          },
        ),
      );
    } else {
      Get.dialog(
        ConfirmDialogWidget(
          title: "Xác nhận",
          content: "Bạn có chắc chắn muốn xóa giao dịch này?",
          confirmText: "Xóa",
          cancelText: "Hủy",
          onConfirm: () {
            Get.back();
            _executeDelete();
          },
        ),
      );
    }
  }

  Future<void> _executeDelete() async {
    showLoading();

    final result = await ErrorHandler.execute(() async {
      await _transactionRepository.deleteTransaction(
        transaction: transaction,
        currentCategory: category.value,
      );
    }, tag: "DELETE_TRANSACTION");

    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage("Lỗi", "Không thể xóa giao dịch: ${failure.message}");
      },
      (_) {
        Get.back();
        showSuccessMessage("Thành công", "Đã xóa giao dịch thành công");
      },
    );
  }

  String getImageUrl(String fileId) {
    return _storageRepo.getImageUrl(fileId);
  }

  Future<void> onEditTransaction() async {
    final isExpense = transaction.type == 'EXPENSE';
    dynamic result;
    if (isExpense) {
      result = await Get.toNamed(
        Routes.TRANSACTION_CREATE,
        arguments: {
          'isEdit': true,
          'transaction': transaction,
          'detail': detail.value,
        },
      );
    } else {
      result = await Get.toNamed(
        Routes.WALLETCREATE,
        arguments: {
          'isEdit': true,
          'transaction': transaction,
          'detail': detail.value,
        },
      );
    }

    if (result == true) {
      showSuccessMessage("Thành công", "Đã cập nhật giao dịch thành công");
      _loadData();
    }
  }
}
