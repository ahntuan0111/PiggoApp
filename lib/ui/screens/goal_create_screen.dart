import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:appintern/ui/controllers/goal_create_controller.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:appintern/ui/widgets/emoji_picker_bottom_sheet.dart'
    as import_emoji_picker;

class GoalCreateScreen extends GetView<GoalCreateController> {
  const GoalCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: CircleAvatar(
              radius: 16.r,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, color: Colors.grey[600], size: 20.sp),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gợi ý cho bạn
            Text(
              "Gợi ý cho bạn",
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: [
                _buildSuggestionChip('icon_plane.png', 'Du lịch', 'Du lịch'),
                _buildSuggestionChip('icon_transport.png', 'Xe mới', 'Xe mới'),
                _buildSuggestionChip(
                  'icon_education.png',
                  'Giáo dục',
                  'Giáo dục',
                ),
                _buildSuggestionChip('icon_health.png', 'Nghỉ hưu', 'Nghỉ hưu'),
              ],
            ),
            SizedBox(height: 24.h),

            // Tên mục tiêu
            _buildLabel("TÊN MỤC TIÊU"),
            SizedBox(height: 8.h),
            TextField(
              controller: controller.nameController,
              decoration: InputDecoration(
                hintText: "Ví dụ: Căn hộ mơ ước",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Số tiền mục tiêu
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
              decoration: InputDecoration(
                prefixText: "${CurrencyFormatter.symbol} ",
                prefixStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Ngày hoàn thành dự kiến
            _buildLabel("NGÀY HOÀN THÀNH DỰ KIẾN"),
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: () => controller.pickDate(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey[200]!),
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
                            : "dd/mm/yyyy",
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: controller.selectedDeadline.value != null
                              ? Colors.black87
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                    Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Biểu tượng mục tiêu
            _buildLabel("BIỂU TƯỢNG MỤC TIÊU"),
            SizedBox(height: 8.h),
            Row(
              children: [
                Obx(
                  () => Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCF5D5),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: CustomIconWidget(
                      iconName: controller.selectedIcon.value,
                      size: 24.w,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey[200]!),
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
                            "Thay đổi icon",
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
            SizedBox(height: 24.h),

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
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    elevation: 0,
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
                          "Tạo mục tiêu",
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildSuggestionChip(String iconName, String label, String fillText) {
    return GestureDetector(
      onTap: () {
        controller.nameController.text = fillText;
        controller.selectedIcon.value = iconName;
      },
      child: Container(
        width: (Get.width - 40.w - 12.w) / 2, // 2 cột
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(iconName: iconName, size: 24.w),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
