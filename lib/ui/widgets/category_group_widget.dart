import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/data/models/category_type_model.dart';
import 'package:appintern/data/models/category_model.dart';

class CategoryGroupWidget extends StatelessWidget {
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
            Icon(
              Icons.remove_circle,
              color: const Color(0xFFD64D4D),
              size: 20.r,
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
                      Icon(
                        Icons.remove_circle,
                        color: const Color(0xFFD64D4D),
                        size: 20.r,
                      ),
                      SizedBox(width: 12.w),
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDEBB2),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          cat.iconName,
                          style: TextStyle(fontSize: 18.sp),
                        ), // Tạm dùng Text cho icon
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2E2E2E),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.menu,
                        color: Colors.grey,
                        size: 24.r,
                      ), // Kéo thả
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
