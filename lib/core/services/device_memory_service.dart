import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Dữ liệu bộ nhớ thiết bị thời gian thực từ Platform Channel
class DeviceMemoryInfo {
  final int availMemMb;
  final int totalMemMb;
  final bool isLowMemory;
  final int thresholdMb;

  const DeviceMemoryInfo({
    required this.availMemMb,
    required this.totalMemMb,
    required this.isLowMemory,
    required this.thresholdMb,
  });

  factory DeviceMemoryInfo.fromMap(Map<dynamic, dynamic> map) {
    return DeviceMemoryInfo(
      availMemMb: (map['availMemMb'] as num?)?.toInt() ?? 0,
      totalMemMb: (map['totalMemMb'] as num?)?.toInt() ?? 0,
      isLowMemory: map['isLowMemory'] as bool? ?? false,
      thresholdMb: (map['thresholdMb'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() =>
      'DeviceMemoryInfo(avail: ${availMemMb}MB, total: ${totalMemMb}MB, lowMem: $isLowMemory, threshold: ${thresholdMb}MB)';
}

/// Dịch vụ kiểm tra bộ nhớ Native (Android ActivityManager / iOS os_proc_available_memory)
/// Phục vụ cơ chế bảo vệ RAM cho tính năng On-Device AI
class DeviceMemoryService extends GetxService {
  static const MethodChannel _channel = MethodChannel('com.example.appintern/device_memory');

  /// Đọc thông số bộ nhớ động tại thời điểm gọi
  Future<DeviceMemoryInfo> getMemoryInfo() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getMemoryInfo');
      if (res != null) {
        return DeviceMemoryInfo.fromMap(res);
      }
    } catch (_) {
      // Fallback an toàn cho môi trường test hoặc thiết bị chưa có platform handler
    }
    return const DeviceMemoryInfo(
      availMemMb: 1024,
      totalMemMb: 4096,
      isLowMemory: false,
      thresholdMb: 400,
    );
  }

  /// Kiểm tra xem RAM khả dụng có đạt ngưỡng an toàn để nạp model AI không.
  /// Mặc định: cần tối thiểu [thresholdMb] (700 MB) RAM trống và không bị cảnh báo lowMemory.
  Future<bool> isSafeToLoadAiModel({int thresholdMb = 700}) async {
    final info = await getMemoryInfo();
    if (info.isLowMemory) return false;
    return info.availMemMb >= thresholdMb;
  }
}

