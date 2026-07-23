import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/rollover_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class NewMonthSetupScreen extends GetView<RolloverController> {
  const NewMonthSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1), // Nền Kem
      appBar: AppBar(
        title: Obx(() => Text(
          "Kế hoạch ${controller.newMonthName.value} 👋", 
          style: TextStyle(color: const Color(0xFF0B4A3A), fontWeight: FontWeight.bold, fontSize: 16.sp)
        )),
        centerTitle: true,
        automaticallyImplyLeading: false, // Ngăn back
        backgroundColor: const Color(0xFFF9F7F1),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Income Setup
          Container(
            margin: EdgeInsets.all(24.w),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Dự kiến thu nhập tháng này",
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF369B56), // Xanh lá
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "0đ",
                    hintStyle: TextStyle(color: Colors.grey[300]),
                  ),
                  onChanged: (val) {
                    controller.onExpectedIncomeChanged(val);
                  },
                ),
                Obx(() => controller.hasHardDeficit.value 
                  ? Column(
                      children: [
                        SizedBox(height: 16.h),
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0), // Cam nhạt
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.orange.withOpacity(0.5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 20.sp),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  "Cảnh báo: Bạn đang có khoản nợ kỹ thuật ${formatter.format(controller.deficitAmount.value)}đ. Hệ thống sẽ ưu tiên cấn trừ vào khoản thu nhập này.",
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.orange[900],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    )
                  : const SizedBox.shrink()
                )
              ],
            ),
          ),

          // Categories cloned
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              children: [
                Text(
                  "ĐỊNH MỨC CHI TIÊU KẾ THỪA",
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Icon(Icons.info_outline, size: 16.sp, color: Colors.black38),
              ],
            ),
          ),
          SizedBox(height: 12.h),

          Expanded(
            child: Obx(() => ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              itemCount: controller.clonedCategories.length,
              itemBuilder: (context, index) {
                final cat = controller.clonedCategories[index];
                return _buildCategoryBudgetCard(
                  cat['title'] as String, 
                  cat['icon'] as String, 
                  (cat['budget'] as num).toDouble(), 
                  cat['showAi'] as bool
                );
              },
            )),
          ),

          // Bottom Action
          Padding(
            padding: EdgeInsets.all(24.w),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 60.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B4A3A), // Xanh rêu
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () {
                    // Xong quá trình Rollover, về Home
                    controller.onStartHardReset(); 
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Chốt Ngân Sách & Bắt Đầu!",
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 20.sp),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetCard(String title, String iconName, double currentBudget, bool showAiSuggestion) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7F1),
                  shape: BoxShape.circle,
                ),
                child: CustomIconWidget(iconName: iconName, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp, color: Colors.black87)),
              ),
              if (showAiSuggestion)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC49A45).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: const Color(0xFFC49A45), size: 14.sp),
                      SizedBox(width: 4.w),
                      Text("Đề xuất giảm", style: TextStyle(color: const Color(0xFFC49A45), fontSize: 10.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Text(
                "Định mức:",
                style: TextStyle(fontSize: 13.sp, color: Colors.black54),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F7F1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    "${formatter.format(currentBudget)}đ",
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF369B56)),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
