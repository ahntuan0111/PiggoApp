import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/wallet_controller.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:appintern/data/models/transaction_model.dart';
import 'package:appintern/data/models/transaction_detail_model.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:appintern/core/services/network_service.dart';

class WalletScreen extends GetView<WalletController> {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await controller.fetchWallets();
            await controller.fetchRecentTransactions();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- THẺ TỔNG TÀI SẢN ---
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B4A3A),
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0B4A3A,
                              ).withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24.r),
                          child: Stack(
                            children: [
                              // Background curves painter
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: GoldCurvesPainter(),
                                ),
                              ),
                              // Content
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24.w,
                                  vertical: 32.h,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Tổng ngân sách",
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Icon(
                                          Icons.remove_red_eye,
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          size: 16.sp,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12.h),
                                    Obx(() {
                                      final total = controller
                                          .budgetService
                                          .totalWalletBalance
                                          .value;
                                      return Text(
                                        "${formatter.format(total)}đ",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 36.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }),
                                    SizedBox(height: 32.h),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text(
                                                "Đã phân bổ (Còn lại)",
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  fontSize: 12.sp,
                                                ),
                                              ),
                                              SizedBox(height: 4.h),
                                              Obx(() {
                                                final allocated = controller
                                                    .budgetService
                                                    .allocatedAmount
                                                    .value;
                                                return Text(
                                                  "${formatter.format(allocated)}đ",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 40.h,
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text(
                                                "Chưa phân bổ",
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  fontSize: 12.sp,
                                                ),
                                              ),
                                              SizedBox(height: 4.h),
                                              Obx(() {
                                                final unallocated = controller
                                                    .budgetService
                                                    .unallocatedAmount
                                                    .value;
                                                return Text(
                                                  "${formatter.format(unallocated)}đ",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // --- NÚT HÀNH ĐỘNG ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            icon: Icons.add,
                            label: "Tạo Giao Dịch",
                            onTap: () async {
                              final result = await Get.toNamed(Routes.TRANSACTION_CREATE);
                              if (result == true) {
                                final isOffline = Get.find<NetworkService>().isOffline.value;
                                if (isOffline) {
                                  controller.showSuccessMessage("Đã lưu (Ngoại tuyến)", "Dữ liệu sẽ được đồng bộ khi có mạng");
                                } else {
                                  controller.showSuccessMessage("Thành công", "Đã lưu giao dịch");
                                }
                              }
                            },
                          ),
                          _buildActionButton(
                            icon: Icons.track_changes,
                            label: "Mục Tiêu",
                            onTap: () => Get.toNamed(Routes.GOAL),
                          ),
                          _buildActionButton(
                            icon: Icons.bolt,
                            label: "Điều chỉnh ví",
                            onTap: () async {
                              controller.resetFields();
                              controller.isAdjustMode.value = true;
                              final result = await Get.toNamed(Routes.WALLETCREATE);
                              if (result == true) {
                                final isOffline = Get.find<NetworkService>().isOffline.value;
                                if (isOffline) {
                                  controller.showSuccessMessage(
                                    'Đã lưu (Ngoại tuyến)',
                                    'Dữ liệu sẽ được đồng bộ khi có mạng',
                                  );
                                } else {
                                  controller.showSuccessMessage(
                                    'Thành công',
                                    'Đã cập nhật ngân sách',
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),

                      SizedBox(height: 32.h),

                      // --- LỊCH SỬ GIAO DỊCH ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Lịch sử giao dịch",
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Get.toNamed(Routes.TRANSACTION_HISTORY),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(
                                0xFFEBC14F,
                              ), // Màu vàng cam chủ đạo
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Xem tất cả",
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 16.sp),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),

              // --- DANH SÁCH LỊCH SỬ ---
              Obx(() {
                if (controller.isLoadingWallets.value &&
                    controller.recentTransactions.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (controller.recentTransactions.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.h),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64.sp,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              "Chưa có giao dịch nào",
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = controller.recentTransactions[index];
                      final TransactionModel tx = item['transaction'];
                      final TransactionDetailModel? detail = item['detail'];

                      final bool isExpense = tx.type == 'EXPENSE';
                      final amountColor = isExpense
                          ? const Color(0xFFE53935)
                          : const Color(0xFF4CAF50);
                      final sign = isExpense ? '-' : '+';

                      // Tìm category info (nếu có thể lấy từ budgetService)
                      String categoryName = 'Giao dịch';
                      String iconName = 'icon_wallet.png';
                      final catIndex = controller.budgetService.categories
                          .indexWhere(
                            (c) => c.categoryModel.id == tx.categoryId,
                          );
                      if (catIndex != -1) {
                        final cat =
                            controller.budgetService.categories[catIndex];
                        categoryName = cat.name;
                        iconName = cat.icon;
                      }

                      return InkWell(
                        onTap: () {
                          Get.toNamed(
                            Routes.TRANSACTION_DETAIL,
                            arguments: {'transaction': tx},
                          );
                        },
                        borderRadius: BorderRadius.circular(16.r),
                        child: Container(
                          margin: EdgeInsets.only(
                            bottom: 12.h,
                            left: 16.w,
                            right: 16.w,
                          ),
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            children: [
                              CustomIconWidget(iconName: iconName, size: 24.sp),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      categoryName,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1E1E1E),
                                      ),
                                    ),
                                    if (detail?.note != null &&
                                        detail!.note.isNotEmpty) ...[
                                      SizedBox(height: 4.h),
                                      Text(
                                        detail.note,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "$sign${formatter.format(tx.amount)}đ",
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: amountColor,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(tx.transactionDate),
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: controller.recentTransactions.length > 5
                        ? 5
                        : controller.recentTransactions.length,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64.r,
            height: 64.r,
            decoration: const BoxDecoration(
              color: Color.fromARGB(
                255,
                235,
                193,
                79,
              ), // Màu vàng cam giống nút FAB
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E1E1E),
            ),
          ),
        ],
      ),
    );
  }
}

class GoldCurvesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // --- LỚP MÀU GRADIENT PHÁT SÁNG (GLOW) ---
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFD4AF37).withValues(alpha: 0.0),
              const Color(0xFFD4AF37).withValues(alpha: 0.18),
            ],
          ).createShader(
            Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
          );

    // Dùng một đường cong làm mảng khối cho gradient
    final fillPath = Path();
    fillPath.moveTo(0, size.height * 0.75);
    fillPath.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.9,
      size.width * 0.6,
      size.height * 0.75,
    );
    fillPath.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.6,
      size.width,
      size.height * 0.85,
    );
    fillPath
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);

    // --- CÁC ĐƯỜNG CONG (STROKE) ---
    final baseStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFD4AF37);

    // Đường cong 1 (Nền xa nhất, mờ)
    final path1 = Path();
    path1.moveTo(0, size.height * 0.65);
    path1.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.5,
      size.width * 0.5,
      size.height * 0.7,
    );
    path1.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.9,
      size.width,
      size.height * 0.6,
    );
    canvas.drawPath(
      path1,
      baseStrokePaint
        ..strokeWidth = 1.0
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.2),
    );

    // Đường cong 2 (Mới - Tạo độ rối nhẹ ở giữa)
    final path2 = Path();
    path2.moveTo(0, size.height * 0.85);
    path2.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.6,
      size.width * 0.55,
      size.height * 0.8,
    );
    path2.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.95,
      size.width,
      size.height * 0.7,
    );
    canvas.drawPath(
      path2,
      baseStrokePaint
        ..strokeWidth = 1.2
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.3),
    );

    // Đường cong 3 (Chính giữa, nét đậm và sáng nhất)
    final path3 = Path();
    path3.moveTo(0, size.height * 0.8);
    path3.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.9,
      size.width * 0.6,
      size.height * 0.75,
    );
    path3.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.6,
      size.width,
      size.height * 0.85,
    );
    canvas.drawPath(
      path3,
      baseStrokePaint
        ..strokeWidth = 2.0
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.55),
    );

    // Đường cong 4 (Mới - Cắt ngang lên trên, lượn sóng sâu)
    final path4 = Path();
    path4.moveTo(0, size.height * 0.7);
    path4.quadraticBezierTo(
      size.width * 0.4,
      size.height * 1.0,
      size.width * 0.7,
      size.height * 0.65,
    );
    path4.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.45,
      size.width,
      size.height * 0.75,
    );
    canvas.drawPath(
      path4,
      baseStrokePaint
        ..strokeWidth = 1.5
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.4),
    );

    // Đường cong 5 (Dưới cùng sát mép thẻ)
    final path5 = Path();
    path5.moveTo(0, size.height * 0.92);
    path5.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.75,
      size.width * 0.7,
      size.height * 0.95,
    );
    path5.quadraticBezierTo(
      size.width * 0.85,
      size.height * 1.05,
      size.width,
      size.height * 0.9,
    );
    canvas.drawPath(
      path5,
      baseStrokePaint
        ..strokeWidth = 1.0
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
