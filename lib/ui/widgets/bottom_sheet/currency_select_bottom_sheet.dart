import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/core/theme/app_colors.dart';

class CurrencySelectBottomSheet extends StatefulWidget {
  final String currentCode;
  final Function(String) onSelected;

  const CurrencySelectBottomSheet({
    super.key,
    required this.currentCode,
    required this.onSelected,
  });

  @override
  State<CurrencySelectBottomSheet> createState() => _CurrencySelectBottomSheetState();
}

class _CurrencySelectBottomSheetState extends State<CurrencySelectBottomSheet> {
  String _searchQuery = '';
  
  final List<Map<String, String>> _currencies = [
    {'code': 'VND', 'name': 'Vietnamese Dong', 'flag': 'assets/flags/vnd.png'},
    {'code': 'USD', 'name': 'US Dollar', 'flag': 'assets/flags/usd.png'},
    {'code': 'SGD', 'name': 'Singapore Dollar', 'flag': 'assets/flags/sgd.png'},
    {'code': 'EUR', 'name': 'Euro', 'flag': 'assets/flags/eur.png'},
    {'code': 'GBP', 'name': 'British Pound', 'flag': 'assets/flags/gbp.png'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'flag': 'assets/flags/aud.png'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'flag': 'assets/flags/cad.png'},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredCurrencies = _currencies.where((c) {
      final query = _searchQuery.toLowerCase();
      return c['code']!.toLowerCase().contains(query) || 
             c['name']!.toLowerCase().contains(query);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        top: 8.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Text(
                  'Cài đặt tiền tệ',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm',
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20.sp),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              'Alo bác ơi, chúng tôi không chịu trách nhiệm về tỷ giá hối đoái. Nó chỉ dành cho việc hiển thị tiền tệ.',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredCurrencies.length,
              itemBuilder: (context, index) {
                final currency = filteredCurrencies[index];
                final isSelected = currency['code'] == widget.currentCode;
                
                return InkWell(
                  onTap: () => widget.onSelected(currency['code']!),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    child: Row(
                      children: [
                        // Cờ (Dùng fallback icon tạm nếu chưa có asset PNG)
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF5F5F5),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Image.asset(
                            currency['flag']!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                              Center(child: Text(currency['code']!.substring(0, 1), style: TextStyle(fontWeight: FontWeight.bold))),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currency['code']!,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.text,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                currency['name']!,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        if (isSelected)
                          Icon(Icons.check, color: AppColors.text, size: 24.sp),
                      ],
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
