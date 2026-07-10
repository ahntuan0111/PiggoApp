import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class EmptyCategorySuggestionWidget extends StatelessWidget {
  final VoidCallback onSuggestionTap;

  const EmptyCategorySuggestionWidget({
    super.key,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEBB2), // Màu vàng nhạt giống screenshot
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Text(
            'Tạo danh mục cho ngân sách',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Mỗi danh mục chính là 1 "nhiệm vụ" cho đồng tiền của bạn.\nBạn có thể tự tạo ra cách quản lý tiền của riêng mình hoặc chọn theo các gợi ý mà ứng dụng cho sẵn nha!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFF4A4A4A),
              height: 1.4,
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: onSuggestionTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF9C03C), // Màu cam vàng
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'TẠO TỪ DANH MỤC GỢI Ý',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
            ),
          ),
          // Đã xóa button "Tự tạo danh mục của tôi" theo yêu cầu
        ],
      ),
    );
  }
}
