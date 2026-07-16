import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/ui/controllers/voice_input_controller.dart';
import 'dart:math' as math;

class VoiceInputScreen extends GetView<VoiceInputController> {
  const VoiceInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF9ED), // Màu nền be nhạt (giống ảnh)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.grey, size: 28.sp),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Voice input",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final state = controller.currentState.value;
          
          return Column(
            children: [
              const Spacer(flex: 1),
              
              // ── Trung tâm: Sóng âm thanh ──
              _buildWaveform(state),
              
              const Spacer(flex: 1),
              
              // ── Text Output ──
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: _buildTextOutput(state),
              ),
              
              SizedBox(height: 40.h),
              
              // ── Nút Bấm Thu Âm (Nhấn giữ) ──
              _buildRecordButton(state),
              
              SizedBox(height: 24.h),
              
              // Hướng dẫn
              Text(
                state == VoiceInputState.recording 
                    ? "Nhả ra để kết thúc" 
                    : "Nhấn giữ để nói",
                style: TextStyle(color: Colors.grey, fontSize: 14.sp),
              ),
              
              SizedBox(height: 32.h),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildWaveform(VoiceInputState state) {
    if (state == VoiceInputState.recording || state == VoiceInputState.sttProcessing) {
      return AnimatedBuilder(
        animation: controller.pulseController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(21, (index) {
              // Tính toán độ cao cột sóng mô phỏng
              final isRecording = state == VoiceInputState.recording;
              final t = controller.pulseController.value;
              // Hàm sin để tạo độ nhấp nhô ngẫu nhiên dựa trên thời gian và index
              final heightMultiplier = isRecording ? (math.sin((t * math.pi * 6) + (index * 0.8)).abs()) : 0.2;
              
              // Cột ở giữa cao nhất, thấp dần sang 2 bên
              final centerDist = (10 - index).abs();
              final baseHeight = 100.h - (centerDist * 8.h);
              final finalHeight = math.max(4.h, baseHeight * heightMultiplier);

              return Container(
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                width: 6.w,
                height: finalHeight,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              );
            }),
          );
        },
      );
    }
    
    // Khi đang idle hoặc AI xử lý thì hiện một đường ngang chấm mờ
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(21, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          width: 6.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4.r),
          ),
        );
      }),
    );
  }

  Widget _buildTextOutput(VoiceInputState state) {
    if (state == VoiceInputState.sttProcessing) {
      return Text("Đang chuyển thành văn bản...", 
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16.sp, color: Colors.orange, fontWeight: FontWeight.w500));
    } else if (state == VoiceInputState.aiProcessing) {
      return Column(
        children: [
          Text("\"${controller.rawText.value}\"", 
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16.sp, color: Colors.black87, fontWeight: FontWeight.w600)),
          SizedBox(height: 16.h),
          Text("AI đang bóc tách giao dịch...", 
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: Colors.green)),
        ],
      );
    } else if (controller.rawText.value.isNotEmpty && state == VoiceInputState.idle) {
       return Text("\"${controller.rawText.value}\"", 
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16.sp, color: Colors.black87, fontWeight: FontWeight.w600));
    }
    
    return Text("Ví dụ: Sáng đổ xăng 50k", 
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16.sp, color: Colors.grey[400]));
  }

  Widget _buildRecordButton(VoiceInputState state) {
    bool isRecording = state == VoiceInputState.recording;
    
    return GestureDetector(
      onTapDown: (_) => controller.handlePointerDown(),
      onTapUp: (_) => controller.handlePointerUp(),
      onTapCancel: () => controller.handlePointerUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          color: isRecording ? Colors.orange : const Color(0xFF2C6B4F), // Màu xanh lá đậm giống thiết kế
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? Colors.orange : const Color(0xFF2C6B4F)).withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: isRecording ? 8 : 2,
            )
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop_rounded : Icons.mic,
          color: Colors.white,
          size: isRecording ? 36.sp : 32.sp,
        ),
      ),
    );
  }
}
