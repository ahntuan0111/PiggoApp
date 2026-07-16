import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ConfirmMultipleTransactionsBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> aiParsedDataList;
  final List<String> availableCategories;
  final double unallocatedAmount;
  final Function(List<Map<String, dynamic>>) onConfirmAll;

  const ConfirmMultipleTransactionsBottomSheet({
    super.key,
    required this.aiParsedDataList,
    required this.availableCategories,
    required this.unallocatedAmount,
    required this.onConfirmAll,
  });

  @override
  State<ConfirmMultipleTransactionsBottomSheet> createState() =>
      _ConfirmMultipleTransactionsBottomSheetState();
}

class _ConfirmMultipleTransactionsBottomSheetState
    extends State<ConfirmMultipleTransactionsBottomSheet> {
  late List<Map<String, dynamic>> transactions;
  final formatter = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    // Tạo bản sao (deep copy) để tự do chỉnh sửa trên UI
    transactions = widget.aiParsedDataList.map((tx) {
      final isInflow = tx['type'] == 'inflow';
      String? defaultCategory;
      if (!isInflow) {
        final aiCategory = tx['categoryName'];
        if (aiCategory != null && widget.availableCategories.contains(aiCategory)) {
          defaultCategory = aiCategory;
        }
      }

      return {
        'id': UniqueKey().toString(), // Tạo ID giả để quản lý list
        'type': tx['type'] ?? 'outflow',
        'amountController': TextEditingController(
          text: formatter.format((tx['amount'] as num?)?.toDouble() ?? 0),
        ),
        'noteController': TextEditingController(text: tx['note']?.toString() ?? ''),
        'categoryName': defaultCategory,
      };
    }).toList();
  }

  @override
  void dispose() {
    for (var tx in transactions) {
      (tx['amountController'] as TextEditingController).dispose();
      (tx['noteController'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _removeItem(int index) {
    setState(() {
      final tx = transactions[index];
      (tx['amountController'] as TextEditingController).dispose();
      (tx['noteController'] as TextEditingController).dispose();
      transactions.removeAt(index);
    });
  }

  void _onSaveAll() {
    if (transactions.isEmpty) {
      Get.back();
      return;
    }

    double totalOutflowUnallocated = 0;
    List<Map<String, dynamic>> finalData = [];

    for (var tx in transactions) {
      final amountStr = (tx['amountController'] as TextEditingController)
          .text
          .replaceAll(RegExp(r'[^0-9]'), '');
      final amount = double.tryParse(amountStr) ?? 0;
      final isInflow = tx['type'] == 'inflow';
      final category = tx['categoryName'] as String?;

      if (!isInflow && category == null) {
        totalOutflowUnallocated += amount;
      }

      finalData.add({
        'type': tx['type'],
        'amount': amount,
        'note': (tx['noteController'] as TextEditingController).text,
        'categoryName': category,
      });
    }

    if (totalOutflowUnallocated > widget.unallocatedAmount) {
      Get.snackbar(
        "Lỗi phân bổ",
        "Tổng tiền xuất từ 'Tiền chưa phân bổ' vượt quá số dư hiện tại (${formatter.format(widget.unallocatedAmount)}đ). Vui lòng chọn danh mục cụ thể.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    widget.onConfirmAll(finalData);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85, // Không vượt quá 85% màn hình
      ),
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 16.h,
        bottom: 24.h + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Xác nhận ${transactions.length} giao dịch",
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Get.back(),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          
          if (transactions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: const Text("Không có giao dịch nào được nhận diện."),
            )
          else
            // Danh sách các giao dịch (Scrollable)
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: transactions.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  return _buildTransactionCard(index);
                },
              ),
            ),
          
          SizedBox(height: 16.h),
          // Nút Lưu Tất Cả
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEBC14F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              onPressed: _onSaveAll,
              child: Text(
                "Lưu tất cả (${transactions.length})",
                style: TextStyle(
                  color: const Color(0xFF2E2E2E),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(int index) {
    final tx = transactions[index];
    final isInflow = tx['type'] == 'inflow';
    final amountController = tx['amountController'] as TextEditingController;
    final noteController = tx['noteController'] as TextEditingController;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isInflow ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  isInflow ? "THU" : "CHI",
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: isInflow ? Colors.green[800] : Colors.red[800],
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _removeItem(index),
                child: Icon(Icons.delete_outline, color: Colors.red[300], size: 20.sp),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: "Số tiền",
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  ),
                  onChanged: (value) {
                    final cleanString = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (cleanString.isNotEmpty) {
                      final formatted = formatter.format(int.parse(cleanString));
                      amountController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String?>(
                  value: tx['categoryName'],
                  isExpanded: true,
                  style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Danh mục",
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    filled: isInflow,
                    fillColor: isInflow ? Colors.grey[200] : null,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text("Chưa phân bổ"),
                    ),
                    if (!isInflow)
                      ...widget.availableCategories.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat, overflow: TextOverflow.ellipsis),
                          )),
                  ],
                  onChanged: isInflow
                      ? null
                      : (value) {
                          setState(() {
                            tx['categoryName'] = value;
                          });
                        },
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: noteController,
            style: TextStyle(fontSize: 13.sp),
            decoration: const InputDecoration(
              labelText: "Ghi chú",
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}
