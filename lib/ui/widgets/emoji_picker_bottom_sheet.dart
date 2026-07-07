import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class EmojiPickerBottomSheet extends StatelessWidget {
  final RxString selectedIcon;

  const EmojiPickerBottomSheet({super.key, required this.selectedIcon});

  @override
  Widget build(BuildContext context) {
    final List<String> icons = [
      '1.png',
      '2.png',
      '3.png',
      '4.png',
      '5.png',
      '6.png',
      '7.png',
      '8.png',
      '9.png',
      '10.png',
      '11.png',
      '12.png',
    ];

    return Container(
      height: 400.h,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      child: Column(
        children: [
          Text(
            "Chọn Icon",
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 10.h,
              ),
              itemCount: icons.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    selectedIcon.value = icons[index];
                    Get.back(); // Đóng bảng chọn icon
                  },
                  child: Center(
                    child: CustomIconWidget(
                      iconName: icons[index],
                      size: 32.sp,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
