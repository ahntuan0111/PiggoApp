import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:get/get.dart';

class ConfirmTransactionBottomSheet extends StatefulWidget {
  final Map<String, dynamic> aiParsedData;
  final List<String> availableCategories;
  final double unallocatedAmount;
  final Future<void> Function(Map<String, dynamic>) onConfirm;

  const ConfirmTransactionBottomSheet({
    super.key,
    required this.aiParsedData,
    required this.availableCategories,
    required this.unallocatedAmount,
    required this.onConfirm,
  });

  @override
  State<ConfirmTransactionBottomSheet> createState() =>
      _ConfirmTransactionBottomSheetState();
}

class _ConfirmTransactionBottomSheetState
    extends State<ConfirmTransactionBottomSheet> {
  late TextEditingController amountController;
  late TextEditingController noteController;
  String? selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(
      text: CurrencyFormatter.format(widget.aiParsedData['amount'] ?? 0),
    );
    noteController = TextEditingController(
      text: widget.aiParsedData['note'] ?? '',
    );

    if (widget.aiParsedData['type'] == 'inflow') {
      selectedCategory = null;
    } else {
      final aiCategory = widget.aiParsedData['categoryName'];
      if (aiCategory != null &&
          widget.availableCategories.contains(aiCategory)) {
        selectedCategory = aiCategory;
      } else {
        selectedCategory = null;
      }
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isInflow = widget.aiParsedData['type'] == 'inflow';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 16.h,
        bottom: 24.h, // Fixed padding issue causing huge whitespace
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Xác nhận giao dịch",
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
            SizedBox(height: 16.h),

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Số tiền",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                
              ),
              onChanged: (value) {
                final cleanString = value.replaceAll(RegExp(r'[^0-9]'), '');
                if (cleanString.isNotEmpty) {
                  final formatted = NumberFormat(
                    '#,###',
                    'vi_VN',
                  ).format(int.parse(cleanString));
                  amountController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                }
              },
            ),
            SizedBox(height: 12.h),

            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: "Ghi chú",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
            SizedBox(height: 12.h),

            DropdownButtonFormField<String?>(
              value: selectedCategory,
              menuMaxHeight: 220, // Giới hạn chiều cao hiển thị khoảng 3-4 mục
              decoration: InputDecoration(
                labelText: "Danh mục",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: isInflow,
                fillColor: isInflow ? Colors.grey[200] : null,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("Tiền chưa phân bổ"),
                ),
                if (!isInflow)
                  ...widget.availableCategories.map(
                    (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                  ),
              ],
              onChanged: isInflow
                  ? null
                  : (value) {
                      setState(() {
                        selectedCategory = value;
                      });
                    },
            ),
            if (isInflow)
              Padding(
                padding: EdgeInsets.only(top: 8.h, left: 4.w),
                child: Text(
                  "Thu nhập sẽ tự động chuyển vào Tiền chưa phân bổ",
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.green[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            SizedBox(height: 24.h),

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
                onPressed: _isLoading
                    ? null
                    : () async {
                        final amountStr = amountController.text.replaceAll(
                          RegExp(r'[^0-9]'),
                          '',
                        );
                        final amount = double.tryParse(amountStr) ?? 0;

                        if (!isInflow && selectedCategory == null) {
                          if (widget.unallocatedAmount == 0) {
                            Get.snackbar(
                              "Lỗi",
                              "Tiền chưa phân bổ hiện tại là 0. Vui lòng chọn một danh mục cụ thể hoặc điều chỉnh ngân sách.",
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                            return;
                          }
                          if (amount > widget.unallocatedAmount) {
                            Get.snackbar(
                              "Lỗi",
                              "Tiền chưa phân bổ không đủ (${CurrencyFormatter.format(widget.unallocatedAmount)}đ). Vui lòng chọn một danh mục cụ thể.",
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                            return;
                          }
                        }

                        setState(() => _isLoading = true);
                        try {
                          await widget.onConfirm({
                            'type': widget.aiParsedData['type'],
                            'amount': amount,
                            'note': noteController.text,
                            'categoryName': selectedCategory,
                          });
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                child: _isLoading
                    ? SizedBox(
                        height: 24.h,
                        width: 24.h,
                        child: const CircularProgressIndicator(
                          color: Color(0xFF2E2E2E),
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        "Xác nhận",
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
      ),
    );
  }
}
