import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/budget_settings_controller.dart';
import 'package:appintern/ui/widgets/bottom_sheet/currency_select_bottom_sheet.dart';
import 'package:appintern/ui/widgets/bottom_sheet/number_format_bottom_sheet.dart';
import 'package:appintern/ui/widgets/bottom_sheet/symbol_position_bottom_sheet.dart';
import 'package:appintern/core/routes/app_routes.dart';

class BudgetSettingsScreen extends GetView<BudgetSettingsController> {
  const BudgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: const Color(0xFF1E1E1E), size: 24.sp),
          onPressed: () {
            // Force reload entire app when going back to apply changes
            Get.offAllNamed(Routes.MAIN);
          },
        ),
        title: Text(
          'Cài đặt tiền tệ',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        final currencyCode = controller.currencyCode.value;
        final symbol = controller.currencySymbol;
        
        return ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            _buildSettingItem(
              title: 'Tiền tệ',
              value: '$currencyCode - $symbol',
              onTap: () {
                Get.bottomSheet(
                  CurrencySelectBottomSheet(
                    currentCode: currencyCode,
                    onSelected: (code) {
                      controller.saveSettings(code, controller.numberFormat.value, controller.symbolPosition.value);
                      Get.back();
                    },
                  ),
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                );
              },
            ),
            SizedBox(height: 12.h),
            _buildSettingItem(
              title: 'Định dạng số tiền',
              value: _getFormatExample(controller.numberFormat.value, symbol, controller.symbolPosition.value),
              onTap: () {
                Get.bottomSheet(
                  NumberFormatBottomSheet(
                    currentFormat: controller.numberFormat.value,
                    symbol: symbol,
                    position: controller.symbolPosition.value,
                    onSelected: (format) {
                      controller.saveSettings(controller.currencyCode.value, format, controller.symbolPosition.value);
                      Get.back();
                    },
                  ),
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                );
              },
            ),
            SizedBox(height: 12.h),
            _buildSettingItem(
              title: 'Vị trí ký hiệu',
              value: _getPositionLabel(controller.symbolPosition.value),
              onTap: () {
                Get.bottomSheet(
                  SymbolPositionBottomSheet(
                    currentPosition: controller.symbolPosition.value,
                    format: controller.numberFormat.value,
                    symbol: symbol,
                    onSelected: (position) {
                      controller.saveSettings(controller.currencyCode.value, controller.numberFormat.value, position);
                      Get.back();
                    },
                  ),
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                );
              },
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSettingItem({required String title, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                color: const Color(0xFF1E1E1E),
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF757575),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(Icons.chevron_right, color: const Color(0xFF757575), size: 20.sp),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getFormatExample(String format, String symbol, String position) {
    String numStr = '123457';
    switch (format) {
      case 'comma':
        numStr = '123,457';
        break;
      case 'dot':
        numStr = '123.457';
        break;
      case 'space':
        numStr = '123 457';
        break;
      case 'none':
        numStr = '123457';
        break;
    }
    
    switch (position) {
      case 'before':
        return '$symbol$numStr';
      case 'hidden':
        return numStr;
      case 'after':
      default:
        return '$numStr$symbol';
    }
  }

  String _getPositionLabel(String position) {
    switch (position) {
      case 'before':
        return 'Trước số tiền';
      case 'hidden':
        return 'Không hiển thị';
      case 'after':
      default:
        return 'Sau số tiền';
    }
  }
}
