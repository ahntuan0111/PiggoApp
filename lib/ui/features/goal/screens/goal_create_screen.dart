import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:appintern/ui/features/goal/controllers/goal_create_controller.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:appintern/ui/features/goal/widgets/goal_saving_card_item.dart';
import 'package:appintern/ui/widgets/emoji_picker_bottom_sheet.dart'
    as import_emoji_picker;

class GoalCreateScreen extends GetView<GoalCreateController> {
  const GoalCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.colorScheme.primary,
            size: 20.sp,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Tạo Mục Tiêu",
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Card
            Text(
              "Xem Trước Thẻ Mục Tiêu",
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12.h),
            _buildRealtimePreview(),
            SizedBox(height: 24.h),

            // Mẫu Quest (Templates)
            Text(
              "Gợi Ý Nhanh",
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: [
                _buildSuggestionChip('icon_plane.png', 'Du lịch', 'Du lịch', isDark),
                _buildSuggestionChip('icon_transport.png', 'Xe mới', 'Xe mới', isDark),
                _buildSuggestionChip(
                  'icon_education.png',
                  'Giáo dục',
                  'Giáo dục',
                  isDark,
                ),
                _buildSuggestionChip('icon_health.png', 'Nghỉ hưu', 'Nghỉ hưu', isDark),
              ],
            ),
            SizedBox(height: 32.h),

            // Form inputs
            _buildLabel("TÊN MỤC TIÊU"),
            SizedBox(height: 8.h),
            TextField(
              controller: controller.nameController,
              decoration: _buildInputDecoration("Ví dụ: Căn hộ mơ ước", isDark),
            ),
            SizedBox(height: 16.h),

            _buildLabel("SỐ TIỀN MỤC TIÊU"),
            SizedBox(height: 8.h),
            TextField(
              controller: controller.targetAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              decoration: _buildInputDecoration("", isDark).copyWith(
                prefixText: "${CurrencyFormatter.symbol} ",
                prefixStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(height: 16.h),

            _buildLabel("THỜI HẠN (KHÔNG BẮT BUỘC)"),
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: () => controller.pickDate(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(
                      () => Text(
                        controller.selectedDeadline.value != null
                            ? DateFormat(
                                'dd/MM/yyyy',
                              ).format(controller.selectedDeadline.value!)
                            : "Không giới hạn",
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: controller.selectedDeadline.value != null
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_month,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),

            _buildLabel("BIỂU TƯỢNG MỤC TIÊU"),
            SizedBox(height: 8.h),
            Row(
              children: [
                Obx(
                  () => Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCF5D5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEBC14F), width: 2),
                    ),
                    child: CustomIconWidget(
                      iconName: controller.selectedIcon.value,
                      size: 32.w,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Get.bottomSheet(
                        import_emoji_picker.EmojiPickerBottomSheet(
                          selectedIcon: controller.selectedIcon,
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit,
                            size: 16.sp,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            "Thay Đổi Biểu Tượng",
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 40.h),

            // Nút Tạo mục tiêu
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: Obx(
                () => ElevatedButton(
                  onPressed: controller.isLoading
                      ? null
                      : () => controller.createGoal(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B4A3A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFF0B4A3A).withValues(alpha: 0.5),
                  ),
                  child: controller.isLoading
                      ? SizedBox(
                          height: 24.h,
                          width: 24.h,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          "Tạo Mục Tiêu",
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEBC14F),
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimePreview() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller.nameController,
      builder: (context, nameValue, _) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller.targetAmountController,
          builder: (context, targetValue, _) {
            return Obx(() {
              final title = nameValue.text.isEmpty ? "Tên Mục Tiêu Của Bạn..." : nameValue.text;
              final targetRaw = targetValue.text.replaceAll(RegExp(r'[^0-9]'), '');
              final target = targetRaw.isEmpty ? 0.0 : double.parse(targetRaw);
              final icon = controller.selectedIcon.value;
              final deadline = controller.selectedDeadline.value;

              String deadlineString = "Không có";
              String timeLeftString = "Vô hạn";
              if (deadline != null) {
                deadlineString = DateFormat('MM/yyyy').format(deadline);
                final now = DateTime.now();
                final difference = deadline.difference(now);
                if (difference.inDays > 30) {
                  timeLeftString = "Còn ${(difference.inDays / 30).floor()} tháng";
                } else if (difference.inDays > 0) {
                  timeLeftString = "Còn ${difference.inDays} ngày";
                } else {
                  timeLeftString = "Đã đến hạn";
                }
              }

              return IgnorePointer( // Không cho tap vào preview
                child: GoalSavingCardItem(
                  title: title,
                  deadlineString: deadlineString,
                  formattedCurrentAmount: CurrencyFormatter.format(0),
                  formattedTargetAmount: CurrencyFormatter.format(target),
                  progress: 0.0,
                  progressText: "0.0%",
                  timeLeftString: timeLeftString,
                  iconName: icon,
                  isCompleted: false,
                ),
              );
            });
          }
        );
      }
    );
  }

  InputDecoration _buildInputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[500]),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: Color(0xFF0B4A3A), width: 2),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSuggestionChip(String iconName, String label, String fillText, bool isDark) {
    return GestureDetector(
      onTap: () {
        controller.nameController.text = fillText;
        controller.selectedIcon.value = iconName;
      },
      child: Container(
        width: (Get.width - 40.w - 12.w) / 2, // 2 cột
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFEBC14F).withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEBC14F).withValues(alpha: 0.1),
              blurRadius: 10,
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: const BoxDecoration(
                color: Color(0xFFFCF5D5),
                shape: BoxShape.circle,
              ),
              child: CustomIconWidget(iconName: iconName, size: 20.w),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Gợi ý",
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0B4A3A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
