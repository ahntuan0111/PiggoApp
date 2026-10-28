import 'package:get/get.dart';
import 'package:appintern/data/repositories/auth_repository.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class OnboardingController extends BaseController {
  final AuthRepository authRepo = Get.find<AuthRepository>();
  var isGoogleLoading = false.obs;
  
  @override
  void onReady() {
    super.onReady();
    FlutterNativeSplash.remove();
  }

  Future<void> loginWithGoogle() async {
    showLoading();
    isGoogleLoading.value = true;
    final result = await ErrorHandler.execute(
      () => authRepo.loginWithGoogle(),
      tag: "LOGIN_GOOGLE",
    );

    hideLoading();
    isGoogleLoading.value = false;

    await result.fold(
      (failure) async {
        showErrorMessage("Lỗi đăng nhập", failure.message);
      },
      (profile) async {
        await Get.find<BudgetService>().refreshData();
        Get.offAllNamed(Routes.MAIN);
      },
    );
  }
}
