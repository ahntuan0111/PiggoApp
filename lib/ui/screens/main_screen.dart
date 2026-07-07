import "package:appintern/core/routes/app_routes.dart";
import "package:appintern/ui/controllers/main_controller.dart";
import "package:flutter/material.dart";
import "package:flutter_screenutil/flutter_screenutil.dart";
import "package:get/get.dart";
import 'package:flutter_svg/flutter_svg.dart';
import 'package:appintern/ui/screens/home_screen.dart';
import 'package:appintern/ui/screens/profile_screen.dart';
import 'package:appintern/ui/controllers/home_controller.dart';
import 'package:appintern/ui/widgets/dialogs/category_required_dialog.dart';
import 'dart:math' as math;

class MainScreen extends GetView<MainController> {
  MainScreen({super.key});

  final List<Widget> _screens = [
    const HomeScreen(),
    const Text("Ví tiền"),
    const Text("Phân tích"),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF9F7F1), // Figma: #0B011A

          body: Obx(() => _screens[controller.selectedIndex.value]),

          // --- FLOATING ACTION BUTTON --- Figma: 56×56, icon 32×32
          floatingActionButton: Obx(() {
            return Visibility(
              visible: !controller.isFabOpen.value,
              maintainState: true,
              maintainAnimation: true,
              maintainSize:
                  true, // Giữ chỗ cho BottomAppBar có khoảng lõm (notch)
              child: SizedBox(
                width: 56.r, // Figma: 56px
                height: 56.r,
                child: FloatingActionButton(
                  heroTag: null,
                  onPressed: controller.toggleFab,
                  backgroundColor: const Color.fromARGB(255, 235, 193, 79),
                  shape: const CircleBorder(),
                  elevation: 5,
                  child: Icon(Icons.add, color: Colors.white, size: 32.r),
                ),
              ),
            );
          }),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,

          bottomNavigationBar: BottomAppBar(
            color: const Color.fromARGB(255, 243, 237, 217), // Figma: #181818
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            padding: EdgeInsets.zero,

            child: SizedBox(
              height: 56.h, // Figma: 56px
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nhóm bên Trái
                  Expanded(
                    child: Row(
                      children: [
                        _buildNavItem(
                          label: "Ngân sách",
                          index: 0,
                          activeIconPath: 'assets/icons/icon_vi_0.png',
                          inactiveIconPath: 'assets/icons/icon_vi_1.png',
                        ),
                        _buildNavItem(
                          label: "Ví tiền",
                          index: 1,
                          activeIconPath: 'assets/icons/icon_bank_0.png',
                          inactiveIconPath: 'assets/icons/icon_bank_1.png',
                        ),
                      ],
                    ),
                  ),

                  // Khoảng trống ở giữa nhường chỗ cho nút FAB
                  SizedBox(width: 56.w),

                  // Nhóm bên Phải
                  Expanded(
                    child: Row(
                      children: [
                        _buildNavItem(
                          label: "Phân tích",
                          index: 2,
                          activeIconPath: 'assets/icons/icon_chart_0.png',
                          inactiveIconPath: 'assets/icons/icon_chart_1.png',
                        ),
                        _buildNavItem(
                          label: "Cá nhân",
                          index: 3,
                          activeIconPath: 'assets/icons/icon_profile_0.png',
                          inactiveIconPath: 'assets/icons/icon_profile_1.png',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // FAB OVERLAY MENU
        Obx(() {
          if (!controller.isFabOpen.value) return const SizedBox.shrink();
          return _buildFabOverlay(context);
        }),
      ],
    );
  }

  Widget _buildFabOverlay(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animationController,
      builder: (context, child) {
        final double baseBottom = 56.h + MediaQuery.of(context).padding.bottom;
        final double screenHalfWidth = MediaQuery.of(context).size.width / 2;
        final double animValue = controller.animationController.value;

        return Stack(
          children: [
            // Dark overlay (Nhấn vào để đóng)
            Positioned.fill(
              child: GestureDetector(
                onTap: controller.toggleFab,
                child: Container(
                  color: Colors.black.withOpacity(
                    0.7 * animValue.clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),

            // Các nút con
            _buildChildFab(
              context: context,
              label: "Nhập thường",
              icon: Icons.assignment_outlined,
              angle: 5 * math.pi / 6, // Trái (150 độ)
              animValue: animValue,
              baseBottom: baseBottom,
              screenHalfWidth: screenHalfWidth,
              onTap: () async {
                controller.toggleFab();
                // Đợi hiệu ứng đóng FAB hoàn tất rồi mới Push Route
                await Future.delayed(const Duration(milliseconds: 260));
                
                // Kiểm tra trước khi vào tạo giao dịch
                if (Get.isRegistered<HomeController>()) {
                  final homeCtrl = Get.find<HomeController>();
                  if (homeCtrl.categories.isEmpty) {
                    showCategoryRequiredDialog(context);
                    return;
                  }
                }
                
                await Get.toNamed(Routes.TRANSACTION_CREATE);
              },
            ),
            _buildChildFab(
              context: context,
              label: "Nhập nhanh",
              icon: Icons.chat_bubble_outline,
              angle: math.pi / 2, // Trên (90 độ)
              animValue: animValue,
              baseBottom: baseBottom,
              screenHalfWidth: screenHalfWidth,
              onTap: () {
                controller.toggleFab();
                // TODO: Chuyển hướng
              },
            ),
            _buildChildFab(
              context: context,
              label: "Giọng nói",
              icon: Icons.mic_none,
              angle: math.pi / 6, // Phải (30 độ)
              animValue: animValue,
              baseBottom: baseBottom,
              screenHalfWidth: screenHalfWidth,
              onTap: () {
                controller.toggleFab();
                // TODO: Chuyển hướng
              },
            ),

            // Nút FAB Chính (chuyển thành dấu X)
            Positioned(
              bottom: baseBottom - 28.r,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: animValue * math.pi / 4, // Xoay 45 độ thành dấu X
                  child: SizedBox(
                    width: 56.r,
                    height: 56.r,
                    child: FloatingActionButton(
                      heroTag: null, // TRÁNH LỖI DUPLICATE HERO TAG
                      onPressed: controller.toggleFab,
                      backgroundColor: ColorTween(
                        begin: const Color.fromARGB(255, 235, 193, 79),
                        end: const Color(0xFFFDEBB2),
                      ).evaluate(controller.animationController),
                      shape: const CircleBorder(),
                      elevation: 5,
                      child: Icon(
                        Icons.add,
                        color: ColorTween(
                          begin: Colors.white,
                          end: const Color(0xFF2E2E2E),
                        ).evaluate(controller.animationController),
                        size: 32.r,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChildFab({
    required BuildContext context,
    required String label,
    required IconData icon,
    required double angle,
    required double animValue,
    required double baseBottom,
    required double screenHalfWidth,
    required VoidCallback onTap,
  }) {
    // Bán kính nở ra
    final double d = 100.r * animValue;

    // Tọa độ
    final double bottom = baseBottom + d * math.sin(angle) - 36.h;
    final double right = screenHalfWidth - d * math.cos(angle) - 40.w;

    return Positioned(
      bottom: bottom,
      right: right,
      child: Transform.scale(
        scale: math.max(0.001, animValue), // Tránh lỗi render scale=0
        child: Opacity(
          opacity: animValue.clamp(0.0, 1.0),
          child: SizedBox(
            width: 80.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48.r,
                  height: 48.r,
                  child: FloatingActionButton(
                    heroTag: null, // TRÁNH LỖI DUPLICATE HERO TAG
                    onPressed: onTap,
                    backgroundColor: const Color.fromARGB(255, 235, 193, 79),
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: Icon(
                      icon,
                      color: const Color(0xFF2E2E2E),
                      size: 24.r,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Material(
                  type: MaterialType.transparency,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      decoration:
                          TextDecoration.none, // Bắt buộc để xóa gạch dưới
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String activeIconPath,
    required String inactiveIconPath,
    required String label,
    required int index,
  }) {
    return Expanded(
      child: Obx(() {
        bool isSelected = controller.selectedIndex.value == index;

        return GestureDetector(
          onTap: () => controller.changeIndex(index),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                isSelected ? activeIconPath : inactiveIconPath,
                width: 24.r, // Figma: 24px
                height: 24.r,
              ),

              SizedBox(height: 2.h), // Figma: gap 2px

              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFF8CD7A) // Figma: active #FFFFFF
                      : const Color(0xFF616161), // Figma: inactive #616161
                  fontFamily: 'Roboto',
                  fontSize: 12.sp, // Figma: 12px
                  height: 18 / 12, // Figma: lineHeight 18 / fontSize 12
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),

              SizedBox(height: 2.h),

              // Active indicator - Figma: 51×4, bg #F8CD7A, radius 2
              Container(
                height: 4.h, // Figma: 4px
                width: 51.w, // Figma: 51px
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF8CD7A) // Figma: #F8CD7A
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2.r), // Figma: 2px
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
