import 'package:appintern/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AiInsightCardWidget extends StatelessWidget {
  final String insightText;
  final bool isOffline;

  const AiInsightCardWidget({
    super.key,
    required this.insightText,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isOffline
            ? AppColors.gray200
            : const Color(0xFFE8F1FF), // Pastel blue
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isOffline ? Colors.transparent : const Color(0xFFD0E3FF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              isOffline
                  ? 'Cố vấn AI đang nghỉ ngơi. Vui lòng kết nối mạng để nhận phân tích mới nhất.'
                  : insightText,
              style: TextStyle(
                fontSize: 14.sp,
                color: isOffline
                    ? AppColors.textSecondary
                    : const Color(0xFF1E3A8A),
                height: 1.5,
                fontWeight: isOffline ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    if (isOffline) {
      return Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(Icons.wifi_off, color: AppColors.textSecondary, size: 24.r),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: const Color(0xFF253B80),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: const Color(0xFFA5C3FF),
              size: 24.r,
            ),
          ),
        );
      },
      onEnd: () {
        // We can't infinitely loop easily with TweenAnimationBuilder without a stateful widget,
        // but for a simple "breathe" effect this will do a nice entrance.
        // For infinite breathing, we could use an AnimationController.
      },
    );
  }
}
