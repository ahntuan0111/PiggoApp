import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:appintern/core/utils/logger.dart';

class NetworkService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // Trạng thái mạng hiện tại
  final RxBool isOffline = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkConnection();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  Future<void> checkConnection() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      return;
    }
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    bool wasOffline = isOffline.value;

    if (result.isEmpty ||
        (result.length == 1 && result.first == ConnectivityResult.none)) {
      isOffline.value = true;
    } else {
      isOffline.value = false;
    }

    if (wasOffline != isOffline.value) {
      AppLogger.info(
        "NETWORK_SERVICE",
        "📡 Trạng thái mạng thay đổi: ${isOffline.value ? '🔴 Đã mất kết nối (Offline)' : '🟢 Đã có kết nối (Online)'}",
      );
    }
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }
}
