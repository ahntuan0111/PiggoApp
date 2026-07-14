import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:appintern/ui/widgets/no_internet_widget.dart';
import 'dart:async';

class NetworkService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  bool isDialogShowing = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void onInit() {
    super.onInit();
    // Lắng nghe thay đổi mạng
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
    // Kiểm tra trạng thái mạng lần đầu
    checkConnection();
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    bool hasConnection = !results.contains(ConnectivityResult.none);
    
    if (!hasConnection) {
      if (!isDialogShowing) {
        isDialogShowing = true;
        // Bật màn hình lỗi mạng, ko cho bấm ra ngoài
        Get.dialog(
          const NoInternetWidget(),
          barrierDismissible: false,
          useSafeArea: false,
        );
      }
    } else {
      if (isDialogShowing) {
        isDialogShowing = false;
        if (Get.isDialogOpen ?? false) {
          Get.back(); // Tự động đóng dialog khi có mạng
        }
      }
    }
  }

  Future<void> checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChange(results);
  }
}
