import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class HistoryTransactionItem extends StatelessWidget {
  final String categoryName;
  final String note;
  final String walletName;
  final double amount;
  final String type; // 'EXPENSE' or 'INCOME'
  final DateTime date;

  const HistoryTransactionItem({
    Key? key,
    required this.categoryName,
    required this.note,
    required this.walletName,
    required this.amount,
    required this.type,
    required this.date,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
    final formattedAmount = CurrencyFormatter.format(amount);
    final formattedDate = DateFormat('dd/MM/yyyy').format(date);
    final bool isExpense = type == 'EXPENSE';

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFEEEEEE),
            width: 1.h,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bên trái: Tên danh mục & Mô tả
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  note.isNotEmpty ? note : 'Không có mô tả',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF757575),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w), // Khoảng cách giữa 2 phần

          // Bên phải: Tên ví, Số tiền & Ngày tháng
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Badge Tên Ví
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4D3E), // Xanh lá đậm
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  walletName,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              
              // Số tiền
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: isExpense ? '-$formattedAmount' : '+$formattedAmount',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isExpense ? const Color(0xFFE53935) : const Color(0xFF43A047),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4.h),

              // Ngày tháng
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF757575),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
