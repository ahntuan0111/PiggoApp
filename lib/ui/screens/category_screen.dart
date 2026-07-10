import 'package:appintern/data/models/category_type_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/category_controller.dart';
import 'package:appintern/ui/widgets/category_group_widget.dart';
import 'package:appintern/ui/widgets/bottom_sheet/add_category_type_bottom_sheet.dart';
import 'package:appintern/ui/widgets/bottom_sheet/add_category_bottom_sheet.dart';

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
                  // TextButton(
                  //   onPressed: () {
                  //     // TODO: Save logic
                  //     Get.back();
                  //   },
                  //   child: Text(
                  //     "LƯU",
                  //     style: TextStyle(
                  //       fontSize: 16.sp,
                  //       fontWeight: FontWeight.bold,
                  //       color: const Color(0xFFC49A45), // Màu vàng đồng
                  //       letterSpacing: 1.2,
                  //     ),
                  //   ),
                  // ),
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
    Get.bottomSheet(
      const AddCategoryTypeBottomSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showAddCategoryBottomSheet(CategoryTypeModel type) {
    Get.bottomSheet(
      AddCategoryBottomSheet(
        isUpdate: false,
        initialName: '',
        initialIcon: '',
        title: 'Thêm danh mục mới',
        buttonText: 'LƯU',
        onSave: (name, icon) {
          controller.createCategory(type.id, name, icon);
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
