import 'package:appintern/data/models/category_type_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/category_controller.dart';
import 'package:appintern/ui/widgets/category_group_widget.dart';

class CategoryScreen extends GetView<CategoryController> {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F0), // Nền kem
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Navigation Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nút X màu xám
                  InkWell(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD3CFC6), // Màu xám nhạt
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 20.r),
                    ),
                  ),

                  // Chữ LƯU màu vàng
                  TextButton(
                    onPressed: () {
                      // TODO: Save logic
                      Get.back();
                    },
                    child: Text(
                      "LƯU",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFC49A45), // Màu vàng đồng
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Tiêu đề
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                "Chỉnh sửa ngân sách",
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2E2E2E),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // 3. Nút Tạo Nhóm Danh Mục
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: InkWell(
                onTap: () {
                  _showAddCategoryTypeBottomSheet();
                },
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9C03C), // Màu vàng rực
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.create_new_folder,
                        color: const Color(0xFF2E2E2E),
                        size: 20.r,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        "TẠO NHÓM DANH MỤC",
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E2E2E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // 4. Danh sách các nhóm
            Expanded(
              child: Obx(() {
                // LƯU Ý QUAN TRỌNG: Phải đọc categories ở ngoài itemBuilder 
                // để GetX Obx có thể track được sự thay đổi của danh sách categories.
                // Nếu chỉ đọc trong itemBuilder, Obx sẽ không rebuild khi categories thay đổi!
                final currentCategories = controller.categories.toList();

                if (controller.categoryTypes.isEmpty) {
                  return Center(
                    child: Text(
                      "Chưa có dữ liệu danh mục.\nHãy tạo nhóm danh mục trước.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: controller.categoryTypes.length,
                  itemBuilder: (context, typeIndex) {
                    final type = controller.categoryTypes[typeIndex];
                    final cats = currentCategories
                        .where((c) => c.categoryTypeId == type.id)
                        .toList();

                    return CategoryGroupWidget(
                      type: type,
                      categories: cats,
                      onAddCategoryTap: () {
                        _showAddCategoryBottomSheet(type);
                      },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryTypeBottomSheet() {
    final TextEditingController textController = TextEditingController();

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 12.h,
          bottom: Get.mediaQuery.viewInsets.bottom + 24.h,
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
      ),
      isScrollControlled: true, // Cho phép bottom sheet đẩy lên khi có bàn phím
      backgroundColor:
          Colors.transparent, // Nền ngoài trong suốt để bo góc hoạt động
    );
  }

  void _showAddCategoryBottomSheet(CategoryTypeModel type) {
    final TextEditingController nameController = TextEditingController();
    final RxString selectedIcon = '📦'.obs; // Icon mặc định

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 12.h,
          bottom: Get.mediaQuery.viewInsets.bottom + 24.h,
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
              "Thêm danh mục mới",
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
                      child: Text(
                        selectedIcon.value,
                        style: TextStyle(fontSize: 28.sp),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                InkWell(
                  onTap: () {
                    _showEmojiPicker(selectedIcon);
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
                  controller.createCategory(
                    type.id,
                    nameController.text,
                    selectedIcon.value,
                  );
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
                    color: const Color(0xFF2E2E2E),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showEmojiPicker(RxString selectedIcon) {
    // List một số Emoji cơ bản để user chọn mượt mà nhất mà không cần mở bàn phím
    final List<String> emojis = [
      '🍔',
      '☕',
      '🚗',
      '🏠',
      '🛒',
      '👕',
      '🏥',
      '💊',
      '🎓',
      '📚',
      '🎮',
      '🎬',
      '✈️',
      '🚌',
      '🐶',
      '🎁',
      '📱',
      '💻',
      '💼',
      '💰',
      '🍉',
      '🥦',
      '🍺',
      '🏀',
      '⚽',
      '🎸',
      '🎨',
      '✈️',
      '🏝️',
      '💸',
    ];

    Get.bottomSheet(
      Container(
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
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      selectedIcon.value = emojis[index];
                      Get.back(); // Đóng bảng chọn icon
                    },
                    child: Center(
                      child: Text(
                        emojis[index],
                        style: TextStyle(fontSize: 32.sp),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }
}
