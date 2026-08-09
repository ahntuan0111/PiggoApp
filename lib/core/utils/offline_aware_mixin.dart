import 'package:get/get.dart';
import 'package:appintern/core/services/network_service.dart';

mixin OfflineAware on GetxController {
  bool get isOffline => Get.find<NetworkService>().isOffline.value;

  /// Executes an action with an offline fallback.
  /// If the network is online, [onlineAction] is executed.
  /// If the network is offline, [offlineAction] is executed.
  Future<void> executeWithOfflineFallback({
    required Future<void> Function() onlineAction,
    required Future<void> Function() offlineAction,
  }) async {
    if (isOffline) {
      await offlineAction();
    } else {
      await onlineAction();
    }
  }
}
