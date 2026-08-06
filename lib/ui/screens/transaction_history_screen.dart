import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:appintern/core/utils/currency_formatter.dart';
import 'package:get/get.dart';

import 'package:appintern/core/constants/app_assets.dart';
import 'package:appintern/ui/controllers/transaction_history_controller.dart';
import 'package:appintern/data/models/category_model.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/services/network_service.dart';

class TransactionHistoryScreen extends GetView<TransactionHistoryController> {
  TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Lịch sử giao dịch",
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFiltersRow(),
          Expanded(
            child: GetBuilder<TransactionHistoryController>(
              id: 'tx_list',
              builder: (_) {
                if (controller.isLoading &&
                    controller.transactionsList.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.transactionsList.isEmpty) {
                  return _buildEmptyState();
                }

                final groupedData = controller.groupedTransactions;
                final dates = groupedData.keys.toList();

                return RefreshIndicator(
                  onRefresh: () async =>
                      controller.fetchTransactions(isRefresh: true),
                  color: const Color(0xFFEBC14F),
                  child: ListView.builder(
                    controller: controller.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    itemCount:
                        dates.length +
                        (controller.isFetchingMore.value ||
                                (controller.hasReachedMax.value &&
                                    Get.find<NetworkService>().isOffline.value)
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      if (index == dates.length) {
                        if (controller.isFetchingMore.value) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        } else {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: Center(
                              child: Text(
                                "Vui lòng kết nối mạng để xem các giao dịch cũ hơn",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          );
                        }
                      }

                      final dateKey = dates[index];
                      final transactions = groupedData[dateKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 16.h, bottom: 8.h),
                            child: Text(
                              dateKey,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Column(
                              children: transactions
                                  .map(
                                    (txData) => _buildTransactionItem(txData),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: TextField(
        controller: controller.searchController,
        decoration: InputDecoration(
          hintText: "Tìm kiếm bằng mô tả giao dịch...",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16.w),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(bottom: 12.h, left: 16.w, right: 16.w),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(
          () => Row(
            children: [
              // Month Filter
              _buildFilterChip(
                label:
                    "Tháng ${controller.selectedMonth.value.month} ${controller.selectedMonth.value.year}",
                icon: Icons.calendar_month_outlined,
                onTap: () => controller.pickMonth(Get.context!),
              ),
              SizedBox(width: 8.w),

              // Sort Filter
              _buildFilterChip(
                label: controller.sortAscending.value ? "Cũ - Mới" : "Mới - Cũ",
                icon: Icons.sort,
                onTap: controller.toggleSortOrder,
              ),
              SizedBox(width: 8.w),

              // Category Filter
              _buildDropdownFilter<CategoryModel>(
                label: controller.selectedCategory.value?.name ?? "Danh mục",
                items: controller.budgetService.categories
                    .map((c) => c.categoryModel)
                    .toList(),
                value: controller.selectedCategory.value,
                itemLabel: (c) => c.name,
                onChanged: (val) => controller.selectedCategory.value = val,
                onClear: () => controller.selectedCategory.value = null,
              ),
              SizedBox(width: 8.w),

              // Type Filter
              _buildDropdownFilter<String>(
                label: controller.selectedType.value == 'EXPENSE'
                    ? 'Chi tiêu'
                    : controller.selectedType.value == 'INCOME'
                    ? 'Thu nhập'
                    : "Kiểu",
                items: ['EXPENSE', 'INCOME'],
                value: controller.selectedType.value,
                itemLabel: (t) => t == 'EXPENSE' ? 'Chi tiêu' : 'Thu nhập',
                onChanged: (val) => controller.selectedType.value = val,
                onClear: () => controller.selectedType.value = null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16.sp, color: Colors.black87),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required String label,
    required List<T> items,
    required T? value,
    required String Function(T) itemLabel,
    required Function(T?) onChanged,
    required VoidCallback onClear,
  }) {
    final bool isSelected = value != null;

    return PopupMenuButton<T>(
      constraints: BoxConstraints(maxHeight: 250.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      onSelected: onChanged,
      itemBuilder: (BuildContext context) {
        return items.map((T item) {
          return PopupMenuItem<T>(value: item, child: Text(itemLabel(item)));
        }).toList();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEBC14F).withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? const Color(0xFFEBC14F) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: isSelected ? const Color(0xFFEBC14F) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            SizedBox(width: 4.w),
            if (isSelected)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 16.sp,
                  color: const Color(0xFFEBC14F),
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down,
                size: 16.sp,
                color: Colors.black87,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> txData) {
    final tx = txData['transaction'];
    final detail = txData['detail'];
    final bool isExpense = tx.type == 'EXPENSE';
    final sign = isExpense ? '-' : '+';
    final amountColor = isExpense
        ? const Color(0xFFE53935)
        : const Color(0xFF4CAF50);

    String note = "Không có mô tả";
    if (tx.note != null && tx.note.trim().isNotEmpty) {
      note = tx.note;
    } else if (detail?.note != null && detail.note.trim().isNotEmpty) {
      note = detail.note;
    }

    return InkWell(
      onTap: () {
        Get.toNamed(Routes.TRANSACTION_DETAIL, arguments: {'transaction': tx});
      },
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Giao dịch (Thu / Chi)
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: isExpense
                    ? const Color(0xFFE53935).withValues(alpha: 0.1)
                    : const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Image.asset(
                isExpense ? AppAssets.iconExpense : AppAssets.iconIncome,
                width: 24.w,
                height: 24.w,
                errorBuilder: (context, error, stackTrace) => Icon(
                  isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isExpense
                      ? const Color(0xFFE53935)
                      : const Color(0xFF4CAF50),
                  size: 24.w,
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Info Danh mục & Mô tả
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txData['categoryName'],
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    note,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),

            // Số tiền & Ví
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    txData['walletName'],
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  "$sign${CurrencyFormatter.format(tx.amount)}",
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isOffline = Get.find<NetworkService>().isOffline.value;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOffline ? Icons.wifi_off : Icons.search_off,
            size: 64.sp,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              isOffline
                  ? "Vui lòng kết nối mạng để xem lịch sử giao dịch tháng này."
                  : "Không tìm thấy giao dịch nào.",
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
