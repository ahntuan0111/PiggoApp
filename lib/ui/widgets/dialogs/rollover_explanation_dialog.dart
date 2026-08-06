import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RolloverExplanationDialog extends StatefulWidget {
  const RolloverExplanationDialog({super.key});

  @override
  State<RolloverExplanationDialog> createState() =>
      _RolloverExplanationDialogState();
}

class _RolloverExplanationDialogState extends State<RolloverExplanationDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      color: const Color(0xFF0B4A3A),
                      size: 24.r,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "Giải thích thuật ngữ",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Get.back(),
                  borderRadius: BorderRadius.circular(20.r),
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(Icons.close, size: 20.r, color: Colors.black54),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // Content
            SizedBox(
              height: 280.h,
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                physics: const BouncingScrollPhysics(),
                children: [_buildPage1(), _buildPage2(), _buildPage3()],
              ),
            ),
            SizedBox(height: 16.h),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) => _buildDot(index)),
            ),
            SizedBox(height: 24.h),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B4A3A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _currentPage < 2 ? "Tiếp theo" : "Đã hiểu",
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      height: 8.h,
      width: _currentPage == index ? 24.w : 8.w,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? const Color(0xFF0B4A3A)
            : const Color(0xFF0B4A3A).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4.r),
      ),
    );
  }

  Widget _buildPage1() {
    return _buildPageContent(
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF369B56),
      title: "Cộng dồn / Giảm ĐM",
      description:
          "Tác động trực tiếp vào Hũ (Danh mục):\n\n"
          "• Cộng dồn: Tiền thừa tháng cũ sẽ được cộng dồn vào ngân sách Hũ tháng mới (bạn được tiêu nhiều hơn).\n\n"
          "• Giảm ĐM (Giảm Định Mức): Tiền tiêu lố tháng cũ sẽ trừ trực tiếp vào ngân sách Hũ tháng mới (bạn phải thắt lưng buộc bụng).",
    );
  }

  Widget _buildPage2() {
    return _buildPageContent(
      icon: Icons.shield_rounded,
      iconColor: const Color(0xFFC49A45),
      title: "Chuyển DP / Trừ DP",
      description:
          "Tác động vào Quỹ Chưa Phân Bổ (Dự Phòng):\n\n"
          "• Chuyển DP: Rút số tiền thừa về Quỹ Chưa Phân Bổ.\n\n"
          "• Trừ DP: Lấy tiền nhàn rỗi trong Quỹ Chưa Phân Bổ ra để trả nợ cho khoản tiêu lố.\n\n"
          "• Giữ nguyên DP: Bảo toàn số tiền nhàn rỗi trong Quỹ Chưa Phân Bổ sang tháng sau.",
    );
  }

  Widget _buildPage3() {
    return _buildPageContent(
      icon: Icons.savings_rounded,
      iconColor: Colors.blue.shade700,
      title: "Tiết kiệm",
      description:
          "Chuyển tiền vào Mục tiêu tiết kiệm:\n\n"
          "Toàn bộ số dư thừa sẽ được gửi vào một Mục Tiêu Tiết Kiệm (Goal) mà bạn đã thiết lập. "
          "Số tiền này sẽ được tách biệt và không dùng để chi tiêu hàng ngày.",
    );
  }

  Widget _buildPageContent({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F7F1),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28.r),
              ),
              SizedBox(height: 16.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
