import 'package:appintern/ui/widgets/custom_icon_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:appintern/data/models/goal_model.dart';
import 'package:appintern/core/services/budget_service.dart';

class GoalAllocationBottomSheet extends StatefulWidget {
  final double availableAmount;
  final List<GoalModel> goals;
  final Map<String, double> initialAllocations;
  final Function(Map<String, double>) onConfirm;

  const GoalAllocationBottomSheet({
    Key? key,
    required this.availableAmount,
    required this.goals,
    required this.initialAllocations,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<GoalAllocationBottomSheet> createState() =>
      _GoalAllocationBottomSheetState();
}

class _GoalAllocationBottomSheetState extends State<GoalAllocationBottomSheet> {
  late Map<String, TextEditingController> _controllers;
  late Map<String, double> _allocations;

  @override
  void initState() {
    super.initState();
    _allocations = Map.from(widget.initialAllocations);
    _controllers = {};

    for (var goal in widget.goals) {
      double amount = _allocations[goal.categoryId] ?? 0.0;
      _controllers[goal.categoryId] = TextEditingController(
        text: amount > 0 ? CurrencyFormatter.formatNumberOnly(amount) : '',
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _totalAllocated {
    return _allocations.values.fold(0.0, (sum, val) => sum + val);
  }

  double get _remainingAmount {
    return widget.availableAmount - _totalAllocated;
  }

  void _onAmountChanged(String goalId, String value) {
    setState(() {
      double parsed = CurrencyFormatter.parse(value);
      if (parsed > 0) {
        _allocations[goalId] = parsed;
      } else {
        _allocations.remove(goalId);
      }
    });
  }

  void _onMaxPressed(String goalId) {
    double remaining = _remainingAmount;
    if (remaining <= 0) return;

    double current = _allocations[goalId] ?? 0.0;
    double newAmount = current + remaining;

    setState(() {
      _allocations[goalId] = newAmount;
      _controllers[goalId]!.text = CurrencyFormatter.formatNumberOnly(
        newAmount,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    double remaining = _remainingAmount;
    bool isOverLimit = remaining < 0;
    bool hasAllocation = _totalAllocated > 0;
    bool isValid = !isOverLimit && hasAllocation;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Text(
                  "Phân bổ tiền tiết kiệm",
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0B4A3A),
                  ),
                ),
                SizedBox(height: 8.h),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14.sp, color: Colors.black54),
                    children: [
                      const TextSpan(text: "Số tiền khả dụng: "),
                      TextSpan(
                        text: CurrencyFormatter.format(widget.availableAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF369B56),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),

          // Body
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              shrinkWrap: true,
              itemCount: widget.goals.length,
              itemBuilder: (context, index) {
                var goal = widget.goals[index];
                var category = Get.find<BudgetService>().categories
                    .firstWhereOrNull(
                      (c) => c.categoryModel.id == goal.categoryId,
                    )
                    ?.categoryModel;
                String iconName =
                    category?.iconName ?? 'assets/icons/others.png';

                return Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CustomIconWidget(
                          iconName: iconName,
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.name,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              "Mục tiêu: ${CurrencyFormatter.format(goal.targetAmount)}",
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 40.h,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: isOverLimit
                                            ? Colors.red.withOpacity(0.5)
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _controllers[goal.categoryId],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12.w,
                                          vertical: 8.h,
                                        ),
                                        hintText: '0đ',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontWeight: FontWeight.normal,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (val) {
                                        String unformatted = val.replaceAll(
                                          RegExp(r'[^0-9]'),
                                          '',
                                        );
                                        if (unformatted.isNotEmpty) {
                                          double valDouble = double.parse(
                                            unformatted,
                                          );
                                          String formatted =
                                              CurrencyFormatter.formatNumberOnly(
                                                valDouble,
                                              );
                                          _controllers[goal.categoryId]!
                                              .value = TextEditingValue(
                                            text: formatted,
                                            selection: TextSelection.collapsed(
                                              offset: formatted.length,
                                            ),
                                          );
                                          _onAmountChanged(
                                            goal.categoryId,
                                            formatted,
                                          );
                                        } else {
                                          _onAmountChanged(
                                            goal.categoryId,
                                            '0',
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                GestureDetector(
                                  onTap: () => _onMaxPressed(goal.categoryId),
                                  child: Container(
                                    height: 40.h,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                    ),
                                    decoration: BoxDecoration(
                                      color: remaining > 0
                                          ? const Color(0xFFE8EEFC)
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "Max",
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: remaining > 0
                                            ? const Color(0xFF2B5CDB)
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Còn lại:",
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(remaining),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: isOverLimit ? Colors.red : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: isValid
                          ? () {
                              widget.onConfirm(_allocations);
                              Get.back();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B4A3A),
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isOverLimit ? "Vượt quá số dư" : "Xác nhận",
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: isValid ? Colors.white : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
