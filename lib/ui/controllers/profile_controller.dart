import 'package:get/get.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/domain/repositories/auth_repository.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/errors/error_handler.dart';

class ProfileController extends BaseController {
  final AuthRepository authRepository = Get.find<AuthRepository>();
  final StorageService storageService = Get.find<StorageService>();

  Future<void> logout() async {
    showLoading();
    final result = await ErrorHandler.execute(() async {
      await authRepository.logout();
    }, tag: 'LOGOUT');
    hideLoading();

    result.fold(
      (failure) {
        showErrorMessage('Lỗi đăng xuất', failure.message);
      },
      (data) {
        storageService.clearAll();
        Get.offAllNamed(Routes.ONBOARDING);
      },
    );
  }
}
