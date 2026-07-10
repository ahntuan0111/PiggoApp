import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/category_controller.dart';

class AddCategoryTypeBottomSheet extends GetView<CategoryController> {
  const AddCategoryTypeBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController textController = TextEditingController();

    return Container(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 12.h,
        bottom: 24.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            "Thêm nhóm hạng mục mới",
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Thêm nhóm hạng mục mới",
              hintStyle: TextStyle(color: Colors.grey, fontSize: 16.sp),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
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
                borderSide: const BorderSide(color: Color(0xFFF9C03C)),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: () {
                controller.createCategoryType(textController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF9C03C), // Màu vàng
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                elevation: 0,
              ),
              child: Text(
                "LƯU",
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E2E2E), // Text đen
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
