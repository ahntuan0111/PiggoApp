import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/constants/app_assets.dart';
import 'package:intl/intl.dart';

class BudgetWarningDialog extends StatefulWidget {
  final double unallocatedAmount;

  const BudgetWarningDialog({Key? key, required this.unallocatedAmount})
    : super(key: key);

  @override
  State<BudgetWarningDialog> createState() => _BudgetWarningDialogState();
}

class _BudgetWarningDialogState extends State<BudgetWarningDialog> {
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
            // 1. Header tĩnh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                      size: 24.r,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "Cảnh báo Ngân sách",
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

            // 2. Nội dung trượt
            SizedBox(
              height: 250.h,
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

            // 3. Dot Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) => _buildDot(index)),
            ),
            SizedBox(height: 24.h),

            // 4. Action Button thay đổi theo trang
            _buildActionButton(),
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
            ? Colors.red.shade800
            : const Color(0xFFFFEBC1),
        borderRadius: BorderRadius.circular(4.r),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_currentPage == 0) {
      return SizedBox(
        width: double.infinity,
        height: 48.h,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 0,
          ),
          child: Text(
            "Tiếp tục",
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (_currentPage == 1) {
      return SizedBox(
        width: double.infinity,
        height: 48.h,
        child: ElevatedButton(
          onPressed: () {
            Get.back();
            Get.toNamed(Routes.BUDGET_DISTRIBUTION);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00604B), // Xanh lá đậm cao cấp
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 0,
          ),
          child: Text(
            "Đến trang Danh mục",
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 48.h,
        child: ElevatedButton(
          onPressed: () => Get.back(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 0,
          ),
          child: Text(
            "Đã hiểu",
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildPage1() {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBC1),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.red.shade800,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.priority_high,
                  color: Colors.white,
                  size: 24.r,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                "Ngân sách vượt mức!",
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                formatCurrency.format(widget.unallocatedAmount),
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          "Hiện tại số tiền phân bổ đang nhiều hơn số dư thực tế trong ví.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.sp, color: Colors.black54, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildPage2() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), // Màu xám nhạt nhẹ nhàng
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  AppAssets.iconWallet,
                  width: 32.r,
                  height: 32.r,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.broken_image, size: 32.r, color: Colors.grey),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                "Thu hồi ngân sách",
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "Gợi ý giảm số tiền phân bổ trong các danh mục khác để bù đắp.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPage3() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), // Màu xám nhạt nhẹ nhàng
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  AppAssets.iconAddBudget,
                  width: 32.r,
                  height: 32.r,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.broken_image, size: 32.r, color: Colors.grey),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                "Bổ sung thu nhập",
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "Chờ nhận lương hoặc nạp thêm tiền vào ví để cân bằng ngân sách.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
