import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class HistoryTransferItem extends StatelessWidget {
  final String action; // 'Chuyển sang' or 'Nhận từ'
  final String partnerName;
  final String partnerIcon;
  final String partnerColor;
  final double amount;
  final String note;
  final DateTime date;

  const HistoryTransferItem({
    Key? key,
    required this.action,
    required this.partnerName,
    required this.partnerIcon,
    required this.partnerColor,
    required this.amount,
    required this.note,
    required this.date,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    final formattedAmount = formatter.format(amount.abs().toInt());
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
    
    final bool isOutbound = amount < 0; // Chuyển đi
    
    // Parse color
    Color parsedColor = const Color(0xFF9E9E9E); // Default grey
    if (partnerColor.startsWith('#') && partnerColor.length == 7) {
      parsedColor = Color(int.parse(partnerColor.substring(1, 7), radix: 16) + 0xFF000000);
    }

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bên trái: Icon đối tác kèm Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: parsedColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CustomIconWidget(
                    iconName: partnerIcon,
                    size: 20.sp,
                  ),
                ),
              ),
              Positioned(
                bottom: -4.r,
                right: -4.r,
                child: Container(
                  padding: EdgeInsets.all(2.r),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOutbound ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
                    size: 14.sp,
                    color: isOutbound ? const Color(0xFFE53935) : const Color(0xFF43A047),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),

          // Giữa: Text mô tả
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFF1E1E1E),
                    ),
                    children: [
                      TextSpan(text: '$action '),
                      TextSpan(
                        text: partnerName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  note.isNotEmpty ? note : formattedDate,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF757575),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),

          // Bên phải: Số tiền
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Badge Cân bằng
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4), // Vàng nhạt
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  'Cân bằng',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: const Color(0xFFF57F17),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              
              Text(
                isOutbound ? '-$formattedAmountđ' : '+$formattedAmountđ',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: isOutbound ? const Color(0xFFE53935) : const Color(0xFF43A047),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
