import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/wallet_model.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';
import 'package:appintern/core/services/appwrite_service.dart';
import 'package:collection/collection.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:appintern/ui/widgets/dialogs/confirm_dialog_widget.dart';

import 'package:appintern/core/routes/app_routes.dart';

class TransactionDetailController extends BaseController with BudgetAware {
  final TransactionRepository _transactionRepository =
      Get.find<TransactionRepository>();
  final AppwriteService _appwrite = Get.find<AppwriteService>();

  late Rx<TransactionModel> rxTransaction;
  TransactionModel get transaction => rxTransaction.value;

  var detail = Rxn<TransactionDetailModel>();
  var category = Rxn<CategoryModel>();
  var wallet = Rxn<WalletModel>();

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

        wallet.value = budgetService.wallets.firstWhereOrNull(
          (w) => w.id == transaction.walletId,
        );

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
    final bucketId =
        dotenv.env['APPWRITE_RECEIPT_BUCKET_ID'] ?? _appwrite.avatarBucketId;
    for (String fileId in fileIds) {
      try {
        final bytes = await _appwrite.storage.getFileView(
          bucketId: bucketId,
          fileId: fileId,
        );
        imageBytes[fileId] = bytes;
      } catch (e) {
        print("Lỗi tải ảnh $fileId: $e");
      }
    }
  }

  void onDeleteTransaction() {
    if (wallet.value == null) return;

    // 1. Dry run
    double futureWalletBalance = wallet.value!.balance;
    double futureUnallocated = budgetService.unallocatedAmount.value;

    if (transaction.type == 'INCOME') {
      futureWalletBalance -= transaction.amount;
      futureUnallocated -= transaction.amount;
    } else {
      futureWalletBalance += transaction.amount;
    }

    // 2. Dialog if negative
    if (futureWalletBalance < 0 || futureUnallocated < 0) {
      Get.dialog(
        ConfirmDialogWidget(
          title: "Cảnh báo nghiêm trọng",
          content:
              "Việc xóa khoản giao dịch này sẽ làm "
              "${futureWalletBalance < 0 ? 'Ví Tiền Mặt' : ''}"
              "${futureWalletBalance < 0 && futureUnallocated < 0 ? ' và ' : ''}"
              "${futureUnallocated < 0 ? 'Tiền Chưa Phân Bổ' : ''}"
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
        currentWallet: wallet.value!,
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
    final bucketId =
        dotenv.env['APPWRITE_RECEIPT_BUCKET_ID'] ?? _appwrite.avatarBucketId;
    final projectId = _appwrite.projectId;
    return '${_appwrite.client.endPoint}/storage/buckets/$bucketId/files/$fileId/view?project=$projectId';
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
      _loadData();
    }
  }
}
