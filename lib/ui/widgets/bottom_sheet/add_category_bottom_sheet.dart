import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/category_controller.dart';
import 'package:appintern/ui/widgets/emoji_picker_bottom_sheet.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class AddCategoryBottomSheet extends StatefulWidget {
  final bool isUpdate;
  final String initialName;
  final String initialIcon;
  final String title;
  final String buttonText;
  final Function(String name, String icon) onSave;

  const AddCategoryBottomSheet({
    super.key, 
    required this.isUpdate,
    required this.initialName,
    required this.initialIcon,
    required this.title,
    required this.buttonText,
    required this.onSave,
  });

  @override
  State<AddCategoryBottomSheet> createState() => _AddCategoryBottomSheetState();
}

class _AddCategoryBottomSheetState extends State<AddCategoryBottomSheet> {
  late final TextEditingController nameController;
  late final RxString selectedIcon;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
    selectedIcon = widget.initialIcon.obs;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 12.h,
        bottom: 24.h,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F1), // Nền màu kem nhạt giống ảnh
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          SizedBox(height: 24.h),

          // Chọn Icon
          Row(
            children: [
              Obx(
                () => Container(
                  width: 56.r,
                  height: 56.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDEBB2),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFFC49A45)),
                  ),
                  child: Center(
                    child: CustomIconWidget(iconName: selectedIcon.value, size: 24.sp),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              InkWell(
                onTap: () {
                  Get.bottomSheet(
                    EmojiPickerBottomSheet(selectedIcon: selectedIcon),
                    backgroundColor: Colors.transparent,
                  );
                },
                child: Text(
                  "Thay đổi",
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFC49A45),
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFFC49A45),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // Tên danh mục
          Text(
            "Tên danh mục",
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF4A4A4A)),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Nhập tên danh mục",
              hintStyle: TextStyle(color: Colors.grey, fontSize: 16.sp),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
              filled: true,
              fillColor: Colors.white,
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
                borderSide: const BorderSide(color: Color(0xFFF9C03C)),
              ),
            ),
          ),

          SizedBox(height: 32.h),

          // Nút Lưu
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: () {
                widget.onSave(nameController.text, selectedIcon.value);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF9C03C), // Màu vàng
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                elevation: 0,
              ),
              child: Text(
                widget.buttonText,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E2E2E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
