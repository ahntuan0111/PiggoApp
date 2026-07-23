import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoadingDialogWidget extends StatelessWidget {
  final String message;
  final String? subMessage;

  const LoadingDialogWidget({
    super.key,
    this.message = "AI đang phân tích...",
    this.subMessage = "Vui lòng chờ trong giây lát",
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Chặn bấm phím Back trên Android khi đang Loading
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon AI & Spinner
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 64.r,
                    height: 64.r,
                    child: const CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEBC14F)),
                      backgroundColor: Color(0xFFFDEBB2),
                    ),
                  ),
                  Icon(
                    Icons.auto_awesome,
                    size: 30.r,
                    color: const Color(0xFFEBC14F),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E2E2E),
                ),
              ),
              if (subMessage != null) ...[
                SizedBox(height: 8.h),
                Text(
                  subMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
