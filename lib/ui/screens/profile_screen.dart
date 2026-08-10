import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/profile_controller.dart';
import 'package:appintern/core/routes/app_routes.dart';

class ProfileScreen extends GetView<ProfileController> {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Cá nhân", style: theme.appBarTheme.titleTextStyle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Obx(() {
        final user = controller.currentUser.value;
        final avatarBytes = controller.avatarBytes.value;
        final syncTasks =
            controller.offlineSync.aiQueueCount.value +
            controller.offlineSync.manualQueueCount.value;

        return ListView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          children: [
            // ==================== A. Identity Section ====================
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: controller.changeAvatar,
                    child: Container(
                      width: 90.w,
                      height: 90.w,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2C2C)
                            : const Color(0xFFE0E0E0),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 4.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: avatarBytes != null
                          ? Image.memory(avatarBytes, fit: BoxFit.cover)
                          : (user != null && user.name.isNotEmpty)
                          ? Center(
                              child: Text(
                                user.name.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 40.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFE0E0E0)
                                      : const Color(0xFF757575),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 45.sp,
                              color: isDark
                                  ? const Color(0xFF757575)
                                  : const Color(0xFF9E9E9E),
                            ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2.w,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 14.sp,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Center(
              child: Text(
                user?.name ?? "Đang tải...",
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: 4.h),
            Center(
              child: Text(
                user?.email ?? "Đang tải...",
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark
                      ? const Color(0xFFA0A0A0)
                      : const Color(0xFF757575),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: syncTasks > 0
                      ? Colors.orange.withValues(alpha: 0.15)
                      : const Color(0xFF369B56).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      syncTasks > 0 ? Icons.sync_problem : Icons.cloud_done,
                      size: 14.sp,
                      color: syncTasks > 0
                          ? Colors.orange
                          : const Color(0xFF369B56),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      syncTasks > 0
                          ? "Đang chờ đồng bộ ($syncTasks)"
                          : "Đã đồng bộ",
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: syncTasks > 0
                            ? Colors.orange
                            : const Color(0xFF369B56),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32.h),

            // ==================== B. Settings Menu ====================

            // Nhóm 1: Tuỳ chỉnh
            Text(
              "TÙY CHỈNH",
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(0xFFA0A0A0)
                    : const Color(0xFF9E9E9E),
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8.h),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: const Text("Định dạng tiền tệ"),
                    subtitle: Text(
                      "Đang dùng: ${controller.settingsService.currencyCode.value}",
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () => Get.toNamed(Routes.BUDGET_SETTINGS),
                  ),
                  // const Divider(),
                  // ListTile(
                  //   leading: const Icon(Icons.dark_mode_outlined),
                  //   title: const Text("Giao diện"),
                  //   trailing: DropdownButton<String>(
                  //     value: controller.settingsService.themeMode.value,
                  //     underline: const SizedBox(),
                  //     icon: const Icon(
                  //       Icons.keyboard_arrow_down,
                  //       color: Colors.grey,
                  //     ),
                  //     items: const [
                  //       DropdownMenuItem(value: 'light', child: Text("Sáng")),
                  //       DropdownMenuItem(value: 'dark', child: Text("Tối")),
                  //     ],
                  //     onChanged: (val) {
                  //       if (val != null) controller.changeThemeMode(val);
                  //     },
                  //   ),
                  // ),
                  const Divider(),
                  Obx(
                    () => SwitchListTile(
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: const Text("Nhắc nhở hàng ngày"),
                      subtitle:
                          controller
                              .settingsService
                              .isDailyReminderEnabled
                              .value
                          ? Text(
                              "Đang bật: ${controller.settingsService.reminderTime.value}",
                            )
                          : const Text("Tắt"),
                      value: controller
                          .settingsService
                          .isDailyReminderEnabled
                          .value,
                      onChanged: (val) {
                        controller.toggleDailyReminder(val);
                      },
                    ),
                  ),
                  Obx(() {
                    if (controller
                        .settingsService
                        .isDailyReminderEnabled
                        .value) {
                      return ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text("Giờ nhắc nhở"),
                        trailing: const Icon(
                          Icons.edit,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onTap: () => controller.changeReminderTime(context),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Nhóm 2: Dữ liệu
            Text(
              "DỮ LIỆU",
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(0xFFA0A0A0)
                    : const Color(0xFF9E9E9E),
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8.h),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text("Trạng thái đồng bộ"),
                    subtitle: syncTasks > 0
                        ? Text("$syncTasks mục đang chờ")
                        : const Text("Mọi thứ đã đồng bộ"),
                    trailing: TextButton(
                      onPressed: controller.forceSync,
                      child: const Text("Đồng bộ ngay"),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.refresh, color: Colors.orange),
                    title: const Text(
                      "Reset Dữ Liệu Tháng Này",
                      style: TextStyle(color: Colors.orange),
                    ),
                    onTap: () {
                      Get.dialog(
                        AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          title: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8.w),
                              const Text("Reset dữ liệu"),
                            ],
                          ),
                          content: const Text(
                            "Hành động này sẽ xóa toàn bộ Ví, Hũ (Categories), Ngân Sách và Giao Dịch để bạn thiết lập lại từ đầu (vẫn giữ phiên đăng nhập).\n\nBạn có chắc chắn muốn thực hiện?",
                            style: TextStyle(height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text(
                                "Hủy",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Get.back();
                                controller.resetAccountData();
                              },
                              child: const Text(
                                "Reset",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Nhóm 3: Tài khoản
            Text(
              "TÀI KHOẢN",
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(0xFFA0A0A0)
                    : const Color(0xFF9E9E9E),
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8.h),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text("Đăng xuất"),
                    onTap: controller.logout,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text(
                      "Xoá tài khoản",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Get.dialog(
                        AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          title: Row(
                            children: [
                              const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8.w),
                              const Text("Xoá tài khoản"),
                            ],
                          ),
                          content: const Text(
                            "Hành động này sẽ xóa vĩnh viễn tài khoản và toàn bộ dữ liệu của bạn trên hệ thống. Không thể khôi phục lại.\n\nBạn có chắc chắn?",
                            style: TextStyle(height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text(
                                "Hủy",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Get.back();
                                controller.deleteAccount();
                              },
                              child: const Text(
                                "Xoá vĩnh viễn",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),
          ],
        );
      }),
    );
  }
}
