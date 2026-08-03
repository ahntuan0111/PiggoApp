import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/controllers/offline_queue_controller.dart';
import 'package:intl/intl.dart';

class OfflineQueueScreen extends GetView<OfflineQueueController> {
  const OfflineQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hàng đợi ngoại tuyến'),
        backgroundColor: const Color(0xFF0B4A3A),
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF369B56)));
        }

        if (controller.queueTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64.sp, color: Colors.grey.shade400),
                SizedBox(height: 16.h),
                Text(
                  'Không có giao dịch nào đang chờ',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16.sp),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: controller.queueTasks.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final task = controller.queueTasks[index];
            return _buildTaskItem(task, controller);
          },
        );
      }),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, OfflineQueueController controller) {
    final status = task['status'] as String;
    final type = task['task_type'] as String;
    final payload = task['payload'] as String;
    
    // Parse created_at
    DateTime createdAt = DateTime.now();
    try {
      createdAt = DateTime.parse(task['created_at']);
    } catch (_) {}
    final timeStr = DateFormat('HH:mm - dd/MM/yyyy').format(createdAt);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'PENDING':
        statusColor = Colors.orange;
        statusText = 'Đang chờ mạng';
        statusIcon = Icons.wifi_off;
        break;
      case 'PROCESSING':
        statusColor = Colors.blue;
        statusText = 'Đang xử lý AI...';
        statusIcon = Icons.sync;
        break;
      case 'NEEDS_CONFIRMATION':
        statusColor = const Color(0xFF369B56);
        statusText = 'Cần xác nhận';
        statusIcon = Icons.fact_check;
        break;
      case 'FAILED':
        statusColor = Colors.red;
        statusText = 'Lỗi xử lý';
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
        statusIcon = Icons.info_outline;
    }

    String typeText = type == 'TEXT' ? 'Văn bản' : type == 'IMAGE' ? 'Hóa đơn' : 'Giọng nói';
    IconData typeIcon = type == 'TEXT' ? Icons.chat : type == 'IMAGE' ? Icons.receipt : Icons.mic;

    return InkWell(
      onTap: status == 'NEEDS_CONFIRMATION' ? () => controller.handleTaskTap(task) : null,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: status == 'NEEDS_CONFIRMATION' ? const Color(0xFF369B56) : Colors.grey.shade200,
            width: status == 'NEEDS_CONFIRMATION' ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(typeIcon, size: 20.sp, color: Colors.grey.shade600),
                    SizedBox(width: 8.w),
                    Text(
                      typeText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              type == 'IMAGE' ? '[Ảnh Hóa Đơn]' : payload,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14.sp, color: statusColor),
                      SizedBox(width: 6.w),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'NEEDS_CONFIRMATION')
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16.sp,
                    color: const Color(0xFF369B56),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
