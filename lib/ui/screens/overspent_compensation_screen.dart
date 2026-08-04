import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/overspent_compensation_controller.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:appintern/core/utils/currency_formatter.dart';

class OverspentCompensationScreen
    extends GetView<OverspentCompensationController> {
  const OverspentCompensationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: Colors.white, size: 16.sp),
          ),
          onPressed: () => Get.back(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Hide keyboard before saving
              FocusScope.of(context).unfocus();
              controller.saveCompensation();
            },
            child: Text(
              'LƯU',
              style: TextStyle(
                color: const Color(0xFFB58D3D), // Màu vàng đậm
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              Text(
                "Bù đắp chi tiêu vượt mức",
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "Bù chi tiêu vượt mức bằng danh mục từ tháng hiện tại hoặc tháng sau.",
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF616161),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24.h),

              // Banner Trạng Thái
              Obx(() => _buildStatusBanner()),

              SizedBox(height: 24.h),

              // Danh sách nguồn tiền
              Obx(() {
                return Column(
                  children: List.generate(
                    controller.sources.length,
                    (index) => _buildSourceCard(index),
                  ),
                );
              }),

              // Nút Thêm nguồn tiền
              GestureDetector(
                onTap: () => controller.openSelectSourceBottomSheet(),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  // Vẽ viền đứt nét ở đây. Tạm dùng viền liền mỏng
                  child: CustomPaint(
                    painter: DashedRectPainter(color: const Color(0xFFB58D3D)),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: const Color(0xFFB58D3D),
                              size: 16.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              "THÊM NGUỒN TIỀN",
                              style: TextStyle(
                                color: const Color(0xFFB58D3D),
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final formatter = NumberFormat('#,###', 'vi_VN');
    final isFullyCompensated = controller.isFullyCompensated;
    final bgColor = isFullyCompensated
        ? const Color(0xFFC8E6C9)
        : const Color(0xFFFFCDD2); // Xanh lục nhạt hoặc đỏ nhạt
    final textColor = isFullyCompensated
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828); // Xanh đậm hoặc đỏ đậm

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomIconWidget(
                iconName: controller.targetBudget.categoryModel.iconName,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                controller.targetBudget.categoryModel.name,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          RichText(
            text: TextSpan(
              text: formatter.format(controller.newRemaining),
              style: TextStyle(
                fontSize: 36.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              children: [
                TextSpan(
                  text: 'đ',
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: textColor,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              isFullyCompensated
                  ? "Đã điều chỉnh khoản vượt mức"
                  : "Đang tiêu vượt mức",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(int index) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    final source = controller.sources[index];
    final textController = controller.textControllers[index]!;

    // Khởi tạo text ban đầu nếu controller trống và có amount
    if (textController.text.isEmpty && source.amountToCompensate > 0) {
      textController.text = formatter.format(source.amountToCompensate);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bù số tiền:",
            style: TextStyle(fontSize: 12.sp, color: const Color(0xFF616161)),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: textController,
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: 'đ ',
              prefixStyle: TextStyle(
                fontSize: 16.sp,
                color: const Color(0xFF1E1E1E),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 12.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: Color(0xFFB58D3D)),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyFormatter(),
            ],
            onChanged: (value) {
              final cleanString = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (cleanString.isEmpty) {
                controller.updateSourceAmount(index, 0);
              } else {
                double parsed = double.tryParse(cleanString) ?? 0;
                // Giới hạn không cho nhập lố số tiền khả dụng
                if (parsed > source.availableAmount) {
                  parsed = source.availableAmount;
                  String formatted = formatter.format(parsed);
                  textController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                }
                controller.updateSourceAmount(index, parsed);
              }
            },
          ),
          SizedBox(height: 16.h),
          Text(
            "Lấy từ:",
            style: TextStyle(fontSize: 12.sp, color: const Color(0xFF616161)),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCF5D5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CustomIconWidget(
                    iconName: source.iconName,
                    size: 20.sp,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.sourceName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        text: 'Còn lại: ',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF616161),
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${formatter.format(source.availableAmount - source.amountToCompensate)}đ',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: source.sourceId == 'unallocated'
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFF616161),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: const Color(0xFF616161),
                  size: 20.sp,
                ),
                onPressed: () => controller.openSelectSourceBottomSheet(
                  indexToReplace: index,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: const Color(0xFFE53935),
                  size: 20.sp,
                ),
                onPressed: () => controller.removeSource(index),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom Painter cho viền đứt nét (Dashed Border)
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint dashedPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double x = 0;
    double y = 0;

    Path path = Path();

    // Top edge
    while (x < size.width) {
      path.moveTo(x, 0);
      path.lineTo(x + gap, 0);
      x += gap * 2;
    }

    // Right edge
    while (y < size.height) {
      path.moveTo(size.width, y);
      path.lineTo(size.width, y + gap);
      y += gap * 2;
    }

    x = size.width;
    // Bottom edge
    while (x > 0) {
      path.moveTo(x, size.height);
      path.lineTo(x - gap, size.height);
      x -= gap * 2;
    }

    y = size.height;
    // Left edge
    while (y > 0) {
      path.moveTo(0, y);
      path.lineTo(0, y - gap);
      y -= gap * 2;
    }

    canvas.drawPath(path, dashedPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
