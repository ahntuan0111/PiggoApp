import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/data/repositories/rollover_repository.dart';
import 'package:appintern/data/repositories/transaction_repository.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';

class MultiMonthGapController extends BaseController {
  final RolloverRepository rolloverRepository = Get.find<RolloverRepository>();
  final BudgetService budgetService = Get.find<BudgetService>();

  var lastActiveMonthYear = "".obs;
  var currentMonthYear = "".obs;

  @override
  void onInit() {
    super.onInit();
    currentMonthYear.value =
        "Tháng ${DateTime.now().month}, ${DateTime.now().year}";
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['lastActiveMonthYear'] != null) {
      lastActiveMonthYear.value = args['lastActiveMonthYear'];
    }
  }

  Future<void> onStartFresh() async {
    showLoading();

    // Đảm bảo dữ liệu mới nhất
    await budgetService.refreshData();

    final result = await ErrorHandler.execute(() async {
      final currentBalance = budgetService.totalWalletBalance.value;

      // 1. Dọn dẹp số dư ví cũ bằng giao dịch Adjustment (nếu có số dư)
      if (currentBalance != 0) {
        final txRepo = Get.find<TransactionRepository>();
        final now = DateTime.now();
        DateTime txDate;
        if (lastActiveMonthYear.value.length == 7) {
          int oldM =
              int.tryParse(lastActiveMonthYear.value.substring(0, 2)) ??
              now.month;
          int oldY =
              int.tryParse(lastActiveMonthYear.value.substring(3)) ?? now.year;
          // Đặt giao dịch vào giây cuối cùng của tháng hoạt động cuối cùng
          txDate = DateTime(oldY, oldM + 1, 0, 23, 59, 59);
        } else {
          // Fallback: ngày cuối cùng của tháng trước
          txDate = DateTime(now.year, now.month, 0, 23, 59, 59);
        }

        final tx = TransactionModel(
          id: '',
          categoryId: '', // Wallet Adjustment thực sự
          amount: currentBalance.abs(),
          type: currentBalance > 0 ? 'EXPENSE' : 'INCOME',
          transactionDate: txDate,
          status: 'COMPLETED',
          note: 'Reset hệ thống (Bỏ trống nhiều tháng)',
        );
        final det = TransactionDetailModel(
          id: '',
          transactionId: '',
          note: 'Dọn dẹp đa tháng',
          receiptFileIds: [],
          rawInputText: '',
          confidenceScore: 1.0,
        );
        await txRepo.createWalletAdjustmentTransaction(
          transaction: tx,
          transactionDetail: det,
        );
      }

      // 2. Dọn dẹp budget rác
      await rolloverRepository.executeHardReset(
        budgetService.currentUserId.value,
      );
    }, tag: "EXECUTE_HARD_RESET");

    hideLoading();

    result.fold((failure) => showErrorMessage("Lỗi", failure.message), (_) {
      budgetService.refreshData(); // Cập nhật lại dữ liệu
      Get.offAllNamed(Routes.MAIN); // Đưa về màn chính
    });
  }
}
