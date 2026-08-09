import 'dart:async';
import 'dart:io';
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
      _setOffline(true);
      return;
    }

    if (result.isEmpty ||
        (result.length == 1 && result.first == ConnectivityResult.none)) {
      _setOffline(true);
    } else {
      await _verifyInternetAccess();
    }
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    if (result.isEmpty ||
        (result.length == 1 && result.first == ConnectivityResult.none)) {
      _setOffline(true);
    } else {
      await _verifyInternetAccess();
    }
  }

  Future<void> _verifyInternetAccess() async {
    try {
      final lookupResult = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      _setOffline(
        lookupResult.isEmpty || lookupResult.first.rawAddress.isEmpty,
      );
    } on SocketException catch (_) {
      _setOffline(true);
    } on TimeoutException catch (_) {
      _setOffline(true);
    }
  }

  void _setOffline(bool value) {
    if (isOffline.value != value) {
      isOffline.value = value;
      AppLogger.info(
        "NETWORK_SERVICE",
        "📡 Trạng thái mạng thay đổi: ${value ? '🔴 Đã mất kết nối (Offline)' : '🟢 Đã có kết nối (Online)'}",
      );
    }
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }
}
