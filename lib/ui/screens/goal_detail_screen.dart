import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/controllers/goal_detail_controller.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:appintern/ui/widgets/history_transaction_item.dart';
import 'package:appintern/ui/widgets/emoji_picker_bottom_sheet.dart' as import_emoji_picker;
import 'package:appintern/data/models/transaction_model.dart';


class GoalDetailScreen extends GetView<GoalDetailController> {
  const GoalDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final NumberFormat formatter = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F7F1),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: const Color(0xFF0B4A3A), size: 20.sp),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Chi tiết mục tiêu",
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0B4A3A),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: const Color(0xFF0B4A3A), size: 22.sp),
            onPressed: () => _showUpdateDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red, size: 24.sp),
            onPressed: () => _showDeleteConfirm(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshAll,
        color: const Color(0xFF0B4A3A),
        child: Obx(() {
          final goal = controller.goal.value;
          final progress = controller.currentProgress;
          final saved = controller.savedAmount;

          return Column(
            children: [

            // Thông tin tiến độ (Vòng tròn)
            Container(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: SizedBox(
                  width: 180.w,
                  height: 180.w,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12.w,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0B4A3A)),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${(progress * 100).toStringAsFixed(1)}%",
                              style: TextStyle(
                                fontSize: 32.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0B4A3A),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              "Đã đạt được",
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Thông tin cơ bản
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Tên mục tiêu:", style: TextStyle(color: Colors.grey[600], fontSize: 14.sp)),
                        Text(goal.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Mục tiêu:", style: TextStyle(color: Colors.grey[600], fontSize: 14.sp)),
                        Text("${formatter.format(goal.targetAmount)} đ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: const Color(0xFF0B4A3A))),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Đã tiết kiệm:", style: TextStyle(color: Colors.grey[600], fontSize: 14.sp)),
                        Text("${formatter.format(saved)} đ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      ],
                    ),
                    if (goal.deadline != null) ...[
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Thời hạn:", style: TextStyle(color: Colors.grey[600], fontSize: 14.sp)),
                          Text(DateFormat('dd/MM/yyyy').format(goal.deadline!), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // Lịch sử giao dịch
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24.r),
                    topRight: Radius.circular(24.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        "Lịch sử nạp tiền",
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      child: controller.isLoading.value
                          ? const Center(child: CircularProgressIndicator())
                          : controller.transactions.isEmpty
                              ? Center(
                                  child: Text(
                                    "Chưa có giao dịch nào.",
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                )
                              : ListView.builder(
                                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                                  itemCount: controller.transactions.length,
                                  itemBuilder: (context, index) {
                                    final item = controller.transactions[index];
                                    final tx = item['transaction'] as TransactionModel;
                                    final detail = item['detail']; // TransactionDetailModel
                                    
                                    final walletName = 'Ngân sách';
                                    final categoryName = controller.budgetService.categories.firstWhereOrNull((c) => c.categoryModel.id == tx.categoryId)?.categoryModel.name ?? 'Mục tiêu';

                                    return HistoryTransactionItem(
                                      categoryName: categoryName,
                                      note: detail?.note ?? tx.note ?? '',
                                      walletName: walletName,
                                      amount: tx.amount,
                                      type: tx.type,
                                      date: tx.transactionDate,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
        }),
      ),
    );
  }

  void _showDeleteConfirm() {
    Get.dialog(

      AlertDialog(
        title: const Text("Xóa mục tiêu"),
        content: const Text("Bạn có chắc chắn muốn xóa mục tiêu này? Danh mục tiết kiệm tương ứng cũng sẽ bị xóa."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteGoal();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: const Text("Xóa", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(BuildContext context) {
    final goal = controller.goal.value;
    final nameController = TextEditingController(text: goal.name);
    final targetController = TextEditingController(text: goal.targetAmount.toInt().toString());
    final deadlineObx = Rxn<DateTime>(goal.deadline);
    
    // Tìm icon hiện tại
    final category = controller.budgetService.categories.firstWhereOrNull((c) => c.categoryModel.id == goal.categoryId);
    final iconObx = (category?.categoryModel.iconName ?? '1.png').obs;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Cập nhật mục tiêu",
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0B4A3A)),
              ),
              SizedBox(height: 24.h),
              
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Tên mục tiêu",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
              SizedBox(height: 16.h),
              
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Số tiền mục tiêu",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
              SizedBox(height: 16.h),
              
              Row(
                children: [
                  Obx(() => CustomIconWidget(iconName: iconObx.value, size: 32.sp)),
                  SizedBox(width: 16.w),
                  TextButton(
                    onPressed: () {
                      Get.bottomSheet(import_emoji_picker.EmojiPickerBottomSheet(selectedIcon: iconObx));
                    },
                    child: const Text("Đổi Icon"),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.grey),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Obx(() => Text(
                      deadlineObx.value == null 
                        ? "Không có thời hạn" 
                        : DateFormat('dd/MM/yyyy').format(deadlineObx.value!),
                    )),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: deadlineObx.value ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        deadlineObx.value = picked;
                      }
                    },
                    child: const Text("Chọn ngày"),
                  ),
                ],
              ),
              
              SizedBox(height: 32.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final target = double.tryParse(targetController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                    if (name.isEmpty || target <= 0) {
                      Get.snackbar("Lỗi", "Vui lòng nhập tên và số tiền hợp lệ");
                      return;
                    }
                    Get.back();
                    controller.updateGoal(name, target, deadlineObx.value, iconObx.value);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B4A3A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: const Text("Lưu thay đổi", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}
