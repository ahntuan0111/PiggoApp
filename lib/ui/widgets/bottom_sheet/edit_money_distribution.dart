import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:appintern/ui/widgets/bottom_sheet/select_source_bottom_sheet.dart';
import 'package:appintern/data/models/budget_category_group.dart';
import 'package:appintern/core/services/budget_service.dart';

import 'package:appintern/ui/widgets/custom_icon_widget.dart';

class EditMoneyDistributionBottomSheet extends StatefulWidget {
  final double initialAllocated;
  final Function(
    double newBudget, {
    String? sourceCategoryId,
    double? sourceCategoryNewBudget,
    String? note,
  })
  onSave;

  final double unallocatedAmount;
  final List<BudgetCategoryGroup> categoryGroups;
  final String currentCategoryId;
  final bool isGoal;

  const EditMoneyDistributionBottomSheet({
    super.key,
    required this.initialAllocated,
    required this.onSave,
    required this.unallocatedAmount,
    required this.categoryGroups,
    required this.currentCategoryId,
    this.isGoal = false,
  });

  @override
  State<EditMoneyDistributionBottomSheet> createState() =>
      _EditMoneyDistributionBottomSheetState();
}

class _EditMoneyDistributionBottomSheetState
    extends State<EditMoneyDistributionBottomSheet> {
  final formatter = NumberFormat('#,###', 'vi_VN');

  late TextEditingController _offsetController;

  bool _isAdding = true;
  double _finalBudget = 0.0;
  double _offsetAmount = 0.0;

  String? _selectedSourceId;
  String? _selectedSourceName;
  double? _selectedSourceAvailableAmount;
  String? _selectedSourceIconName;

  void _executeSave(String? note) {
    if (_selectedSourceId != null) {
      if (_isAdding &&
          _offsetAmount > _selectedSourceAvailableAmount!) {
        Get.snackbar(
          "Lỗi",
          "Nguồn tiền không đủ để lấy. Tối đa chỉ có thể lấy ${NumberFormat('#,###', 'vi_VN').format(_selectedSourceAvailableAmount!)}đ.",
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Tìm category gốc để lấy defaultBudget hiện tại
      double sourceAllocated = 0.0;
      for (var group in widget.categoryGroups) {
        for (var cat in group.categories) {
          if (cat.categoryModel.id == _selectedSourceId) {
            sourceAllocated = cat.categoryModel.defaultBudget;
            break;
          }
        }
      }

      double newSourceBudget;
      if (_isAdding) {
        newSourceBudget = sourceAllocated - _offsetAmount;
      } else {
        newSourceBudget = sourceAllocated + _offsetAmount;
      }
      widget.onSave(
        _finalBudget,
        sourceCategoryId: _selectedSourceId,
        sourceCategoryNewBudget: newSourceBudget,
        note: note,
      );
    } else {
      widget.onSave(_finalBudget, note: note);
    }
  }

  @override
  void initState() {
    super.initState();
    _finalBudget = widget.initialAllocated;
    _offsetController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _offsetController.dispose();
    super.dispose();
  }

  void _calculateFinalBudget() {
    setState(() {
      if (_isAdding) {
        _finalBudget = widget.initialAllocated + _offsetAmount;
      } else {
        _finalBudget = widget.initialAllocated - _offsetAmount;
        if (_finalBudget < 0) _finalBudget = 0;
      }
    });
  }

  void _onOffsetChanged(String value) {
    final cleanString = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanString.isEmpty) {
      _offsetAmount = 0.0;
    } else {
      _offsetAmount = double.tryParse(cleanString) ?? 0.0;
    }

    // Auto-correct nếu vượt quá số dư khả dụng
    if (_isAdding &&
        _selectedSourceAvailableAmount != null &&
        _offsetAmount > _selectedSourceAvailableAmount!) {
      _offsetAmount = _selectedSourceAvailableAmount!;
      String formatted = formatter.format(_offsetAmount);
      _offsetController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    _calculateFinalBudget();
  }

  @override
  Widget build(BuildContext context) {
    bool canSave = _finalBudget != widget.initialAllocated;

    return Container(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 12.h,
        bottom: 24
            .h, // Fixed — GetX isScrollControlled: true đã tự đẩy sheet lên trên keyboard
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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

            // Tieu de
            Center(
              child: Text(
                "Chỉnh sửa số tiền đã phân bổ",
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // Row Da phan bo - Text tinh
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Đã phân bổ",
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF424242),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatter.format(_finalBudget),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        "đ",
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF1E1E1E),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 10.h),

            // Row toggle +/- va offset input
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isAdding = true;
                            _calculateFinalBudget();
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: _isAdding
                                ? const Color(0xFFF9C03C)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 16.r,
                            color: _isAdding
                                ? Colors.white
                                : const Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isAdding = false;
                            _calculateFinalBudget();
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: !_isAdding
                                ? const Color(0xFFF9C03C)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 16.r,
                            color: !_isAdding
                                ? Colors.white
                                : const Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: const Color(0xFFF9C03C)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _offsetController,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            inputFormatters: [CurrencyFormatter()],
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF1E1E1E),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                color: const Color(0xFF9E9E9E),
                              ),
                            ),
                            onChanged: _onOffsetChanged,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          "đ",
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFF9E9E9E),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            Text(
              _isAdding
                  ? "Lấy ${formatter.format(_offsetAmount)}đ từ ${_selectedSourceName ?? '...'}"
                  : "Chuyển ${formatter.format(_offsetAmount)}đ đến ${_selectedSourceName ?? '...'}",
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF616161)),
            ),
            SizedBox(height: 8.h),

            GestureDetector(
              onTap: () {
                Get.bottomSheet(
                  SelectSourceBottomSheet(
                    unallocatedAmount: widget.unallocatedAmount,
                    categoryGroups: widget.categoryGroups,
                    currentCategoryId: widget.currentCategoryId,
                    excludeCategoryIds: Get.find<BudgetService>().goals.map((g) => g.categoryId).toList(),
                    onSelected: (id, name, availableAmount, iconName) {
                      setState(() {
                        _selectedSourceId = id;
                        _selectedSourceName = name;
                        _selectedSourceAvailableAmount = availableAmount;
                        _selectedSourceIconName = iconName;

                        // Auto-correct nếu offsetAmount hiện tại lớn hơn số dư của nguồn mới chọn
                        if (_isAdding && _offsetAmount > availableAmount) {
                          _offsetAmount = availableAmount;
                          String formatted = formatter.format(_offsetAmount);
                          _offsetController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                          _calculateFinalBudget();
                        }
                      });
                    },
                  ),
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                );
              },
              child: _selectedSourceName == null
                  ? DottedBorder(
                      options: RoundedRectDottedBorderOptions(
                        dashPattern: const [5, 3],
                        strokeWidth: 1,
                        radius: Radius.circular(8.r),
                        color: const Color(0xFF9E9D8A),
                        padding: EdgeInsets.zero,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle,
                                color: const Color(0xFF8B7355),
                                size: 16.r,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                "THÊM NGUỒN TIỀN",
                                style: TextStyle(
                                  color: const Color(0xFF8B7355),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: 14.h,
                        horizontal: 16.w,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9C4),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFF9C03C)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CustomIconWidget(
                                iconName: _selectedSourceIconName ?? '💰',
                                size: 24.r,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                _selectedSourceName!,
                                style: TextStyle(
                                  color: const Color(0xFF1E1E1E),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.edit,
                            color: const Color(0xFF8B7355),
                            size: 16.r,
                          ),
                        ],
                      ),
                    ),
            ),

            SizedBox(height: 32.h),

            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: canSave
                    ? () {
                        if (widget.isGoal && !_isAdding) {
                          final noteController = TextEditingController();
                          Get.dialog(
                            AlertDialog(
                              backgroundColor: Colors.white,
                              title: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28.sp),
                                  SizedBox(width: 8.w),
                                  Text("Cảnh báo", style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Việc rút ${formatter.format(_offsetAmount)}đ khỏi quỹ này sẽ làm chậm tiến độ đạt mục tiêu của bạn. Hãy cân nhắc kỹ!",
                                    style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                                  ),
                                  SizedBox(height: 16.h),
                                  TextField(
                                    controller: noteController,
                                    decoration: InputDecoration(
                                      labelText: "Lý do rút tiền *",
                                      border: OutlineInputBorder(),
                                      hintText: "Vd: Kẹt tiền trả tiền nhà",
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(),
                                  child: Text("HỦY", style: TextStyle(color: Colors.grey[600])),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () {
                                    if (noteController.text.trim().isEmpty) {
                                      Get.snackbar("Lỗi", "Vui lòng nhập lý do rút tiền", backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
                                      return;
                                    }
                                    Get.back();
                                    _executeSave(noteController.text.trim());
                                  },
                                  child: Text("XÁC NHẬN RÚT", style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        } else {
                          _executeSave(null);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSave
                      ? const Color(0xFFF9C03C)
                      : const Color(0xFFBDBDBD),
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
                    color: canSave ? const Color(0xFF2E2E2E) : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
