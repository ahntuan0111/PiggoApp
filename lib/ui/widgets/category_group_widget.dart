import 'package:appintern/ui/controllers/category_controller.dart';
import 'package:appintern/ui/widgets/dialogs/confirm_dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/widgets/bottom_sheet/add_category_bottom_sheet.dart';
import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:appintern/core/routes/app_routes.dart';

class CategoryGroupWidget extends GetView<CategoryController> {
  final CategoryTypeModel type;
  final List<CategoryModel> categories;
  final VoidCallback? onAddCategoryTap;

  const CategoryGroupWidget({
    super.key,
    required this.type,
    required this.categories,
    this.onAddCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề Nhóm (Mong muốn, Thiết yếu)
        Row(
          children: [
            GestureDetector(
              onTap: () {
                final isDefault = [
                  'Cố định',
                  'Thiết yếu',
                  'Tiết kiệm',
                ].contains(type.name);

                final dialogContent = isDefault
                    ? '⚠️ CẢNH BÁO: Đây là nhóm mặc định của hệ thống.\n\nBạn có chắc chắn muốn xóa nhóm "${type.name}"?\nTất cả các danh mục con bên trong cũng sẽ bị xóa vĩnh viễn.'
                    : 'Bạn có chắc chắn muốn xóa nhóm "${type.name}"?\nTất cả các danh mục con bên trong cũng sẽ bị xóa.';

                Get.dialog(
                  ConfirmDialogWidget(
                    title: 'Xóa nhóm danh mục',
                    content: dialogContent,
                    onConfirm: () {
                      Get.back(); // Đóng dialog
                      controller.deleteCategoryType(type.id);
                    },
                  ),
                );
              },
              child: Icon(
                Icons.remove_circle,
                color: const Color(0xFFD64D4D),
                size: 20.r,
              ),
            ), // Nút trừ đỏ
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                type.name,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2E2E2E),
                ),
              ),
            ),
            Icon(Icons.arrow_drop_up, color: Colors.grey, size: 24.r),
            Icon(Icons.arrow_drop_down, color: Colors.black87, size: 24.r),
          ],
        ),
        SizedBox(height: 12.h),

        // Nút THÊM DANH MỤC
        InkWell(
          onTap: onAddCategoryTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFC49A45),
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle,
                  color: const Color(0xFFC49A45),
                  size: 18.r,
                ),
                SizedBox(width: 8.w),
                Text(
                  "THÊM DANH MỤC",
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFC49A45),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),

        // Danh sách Item
        ...categories
            .map(
              (cat) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Get.dialog(
                            ConfirmDialogWidget(
                              title: 'Xóa danh mục',
                              content:
                                  'Bạn có chắc chắn muốn xóa danh mục "${cat.name}" này không?',
                              onConfirm: () {
                                Get.back(); // Đóng dialog
                                controller.deleteCategory(cat.id);
                              },
                            ),
                          );
                        },
                        child: Icon(
                          Icons.remove_circle,
                          color: const Color(0xFFD64D4D),
                          size: 20.r,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDEBB2),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Center(
                          child: CustomIconWidget(
                            iconName: cat.iconName,
                            size: 24.sp,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Get.toNamed(Routes.CATEGORY_DETAIL, arguments: cat);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2E2E2E),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Get.bottomSheet(
                            AddCategoryBottomSheet(
                              isUpdate: true,
                              initialName: cat.name,
                              initialIcon: cat.iconName,
                              title: 'Cập nhật danh mục',
                              buttonText: 'CẬP NHẬT',
                              onSave: (name, icon) {
                                controller.updateCategory(
                                  cat.id,
                                  name,
                                  icon,
                                  cat.color,
                                );
                              },
                            ),
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                          );
                        },
                        child: Icon(Icons.menu, color: Colors.grey, size: 24.r),
                      ), // Sửa / Kéo thả
                    ],
                  ),
                ),
              ),
            )
            .toList(),
        SizedBox(height: 24.h),
      ],
    );
  }
}
