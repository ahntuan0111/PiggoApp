import 'package:get/get.dart';
import 'package:appintern/domain/repositories/auth_repository.dart';
import 'package:appintern/domain/repositories/category_repository.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/network/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';

class OnboardingController extends BaseController {
  final AuthRepository authRepo = Get.find<AuthRepository>();
  var isGoogleLoading = false.obs;
  Future<void> loginWithGoogle() async {
    // Kế thừa showLoading() từ BaseController
    showLoading();
    isGoogleLoading.value = true;
    // Sử dụng ErrorHandler.execute từ Dartz như bạn yêu cầu
    final result = await ErrorHandler.execute(
      () => authRepo.loginWithGoogle(),
      tag: "LOGIN_GOOGLE",
    );

    await result.fold(
      (failure) async {
        if (failure.type == 'user_session_already_exists') {
          print(
            "Phát hiện phiên đăng nhập cũ (Google), tự động vào màn chính!",
          );
          final storage = Get.find<StorageService>();
          storage.write(AppKeys.isLoggedIn, true);
          Get.offAllNamed(Routes.MAIN);
        } else {
          hideLoading();
          showErrorMessage("Lỗi đăng nhập", failure.message);
        }
      },
      (_) async {
        try {
          // Lấy thông tin user hiện tại
          final user = await authRepo.getUser();

          try {
            // Tạo CategoryType mặc định theo đúng Schema mới
            final categoryRepo = Get.find<CategoryRepository>();
            await categoryRepo.createDefaultCategoryTypes(user.$id);
          } catch (createError) {
            print("Lỗi tạo mới user profile: $createError");
          }

          final storage = Get.find<StorageService>();
          storage.write(AppKeys.isLoggedIn, true);
          storage.write(AppKeys.userId, user.$id);
          storage.write(AppKeys.userName, user.name);

          hideLoading();
          Get.offAllNamed(Routes.MAIN);
        } catch (e) {
          hideLoading();
          showErrorMessage("Lỗi", "Không thể lưu phiên đăng nhập: $e");
        }
      },
    );
  }
}
