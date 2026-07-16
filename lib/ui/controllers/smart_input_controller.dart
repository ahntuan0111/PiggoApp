import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/domain/services/i_ai_service.dart';
import 'package:appintern/ui/widgets/bottom_sheet/confirm_multiple_transactions_bottom_sheet.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/domain/repositories/transaction_repository.dart';

class SmartInputController extends BaseController with BudgetAware {
  final IAIService aiService = Get.find<IAIService>();
  
  final textController = TextEditingController();
  final isProcessing = false.obs;

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }

  Future<void> submitTextInput() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    isProcessing.value = true;
    
    // Thu thập danh sách các danh mục hợp lệ (loại trừ nhóm Tiết kiệm lâu dài)
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
    }, tag: "PARSE_SMART_INPUT");

    isProcessing.value = false;
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
              "Nội dung bạn nhập có thể không rõ ràng, chứa từ ngữ không phù hợp hoặc kết nối mạng bị gián đoạn. Vui lòng thử lại với câu khác.",
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
        // Mở Form xác nhận nhiều giao dịch
        Get.bottomSheet(
          ConfirmMultipleTransactionsBottomSheet(
            aiParsedDataList: data,
            availableCategories: validCategoryNames,
            unallocatedAmount: budgetService.unallocatedAmount.value,
            onConfirmAll: (confirmedDataList) async {
              showLoading();
              
              final saveResult = await ErrorHandler.execute(() async {
                final txRepo = Get.find<TransactionRepository>();
                
                if (budgetService.wallets.isEmpty) {
                  throw Exception("Bạn chưa có ví nào.");
                }
                final wallet = budgetService.wallets.first;

                // Lặp qua từng giao dịch để lưu
                for (var confirmedData in confirmedDataList) {
                  final catName = confirmedData['categoryName'];
                  CategoryModel? category;
                  if (catName != null) {
                    final budgetCat = budgetService.categories.firstWhereOrNull((c) => c.name == catName);
                    if (budgetCat != null) {
                      category = budgetCat.categoryModel;
                    }
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
                    rawInputText: text, // Ghi lại câu gốc
                    confidenceScore: 0.95,
                  );

                  if (category == null) {
                    await txRepo.createWalletAdjustmentTransaction(
                      transaction: tx,
                      transactionDetail: detail,
                      currentWallet: wallet,
                    );
                  } else {
                    await txRepo.createTransaction(
                      transaction: tx,
                      transactionDetail: detail,
                      currentWallet: wallet,
                      currentCategory: category,
                    );
                  }
                }
              }, tag: "SAVE_MULTIPLE_SMART_TRANSACTIONS");

              hideLoading();

              saveResult.fold(
                (failure) => showErrorMessage("Lỗi", "Không thể lưu giao dịch: ${failure.message}"),
                (_) {
                   Get.back(); // Đóng Bottom Sheet
                   textController.clear();
                   Get.snackbar("Thành công", "Đã ghi nhận ${confirmedDataList.length} giao dịch", 
                     backgroundColor: Colors.green, colorText: Colors.white);
                }
              );
            },
          ),
          isScrollControlled: true,
        );
      },
    );
  }
}
