class OfflineHelper {
  /// Sinh ID tạm cho các bản ghi offline, có dạng offline_{timestamp}
  static String generateTempId([String? suffix]) {
    final base = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    return suffix != null ? '${base}_$suffix' : base;
  }

  /// Kiểm tra xem ID có phải là ID tạm offline không
  static bool isOfflineId(String id) {
    return id.startsWith('offline_');
  }
}
