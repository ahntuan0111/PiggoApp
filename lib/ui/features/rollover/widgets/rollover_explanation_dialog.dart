import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RolloverExplanationDialog extends StatelessWidget {
  const RolloverExplanationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Container(
        padding: EdgeInsets.only(top: 20.h, bottom: 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF369B56), Color(0xFF0B4A3A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0B4A3A).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 24.r,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          "Giải thích thuật ngữ",
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Hiểu rõ các lựa chọn để tối ưu dòng tiền của bạn",
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.black54,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Get.back(),
                    borderRadius: BorderRadius.circular(20.r),
                    child: Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20.r,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade100),

            // Content - Scrollable List
            Flexible(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildTermGroup(
                    title: "Tác động vào Hũ (Danh mục)",
                    iconColor: const Color(0xFF369B56),
                    backgroundColor: const Color(0xFF369B56).withValues(alpha: 0.05),
                    borderColor: const Color(0xFF369B56).withValues(alpha: 0.2),
                    items: [
                      _buildTermItem(
                        title: "Cộng dồn",
                        desc: "Chuyển số tiền dư sang ngân sách tháng mới.",
                        icon: Icons.add_circle_outline_rounded,
                        color: const Color(0xFF369B56),
                      ),
                      _buildTermItem(
                        title: "Giảm Định Mức",
                        desc: "Trừ trực tiếp số tiền đã tiêu lố vào tháng mới.",
                        icon: Icons.remove_circle_outline_rounded,
                        color: Colors.red.shade400,
                        isLast: true,
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _buildTermGroup(
                    title: "Tác động vào Quỹ Dự Phòng",
                    iconColor: const Color(0xFFC49A45),
                    backgroundColor: const Color(0xFFC49A45).withValues(alpha: 0.05),
                    borderColor: const Color(0xFFC49A45).withValues(alpha: 0.2),
                    items: [
                      _buildTermItem(
                        title: "Chuyển Dự Phòng",
                        desc: "Rút tiền thừa từ Hũ về Quỹ chưa phân bổ.",
                        icon: Icons.arrow_circle_right_outlined,
                        color: const Color(0xFFC49A45),
                      ),
                      _buildTermItem(
                        title: "Trừ Dự Phòng",
                        desc: "Lấy tiền nhàn rỗi để bù vào khoản tiêu lố.",
                        icon: Icons.shield_outlined,
                        color: Colors.orange.shade700,
                        isLast: true,
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _buildTermGroup(
                    title: "Tác động Tiết Kiệm",
                    iconColor: Colors.blue.shade600,
                    backgroundColor: Colors.blue.withValues(alpha: 0.05),
                    borderColor: Colors.blue.withValues(alpha: 0.2),
                    items: [
                      _buildTermItem(
                        title: "Tiết kiệm",
                        desc:
                            "Chuyển tiền thừa vào Mục tiêu (Goal), tách biệt khỏi chi tiêu hàng ngày.",
                        icon: Icons.savings_outlined,
                        color: Colors.blue.shade600,
                        isLast: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              child: SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B4A3A),
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
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermGroup({
    required String title,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 16.w, top: 12.h, bottom: 8.h),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8.r, color: iconColor),
                SizedBox(width: 8.w),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildTermItem({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: EdgeInsets.only(left: 50.w),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade200,
            ),
          ),
      ],
    );
  }
}
