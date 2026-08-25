import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/data/repositories/auth_repository.dart';
import 'package:appintern/data/repositories/rollover_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:appintern/core/services/settings_service.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class SplashController extends BaseController {
  final storage = Get.find<StorageService>();

  @override
  void onReady() {
    super.onReady();
    _verifySessionAndFetchData();
  }

  Future<void> _verifySessionAndFetchData() async {
    try {
      final budgetService = Get.find<BudgetService>();
      final network = Get.find<NetworkService>();

      if (network.isOffline.value) {
        if (!budgetService.isDataLoaded.value) {
          await budgetService.refreshData(); // Load cache
        }
        FlutterNativeSplash.remove();
        Get.offAllNamed(Routes.MAIN);
        return;
      }

      final authRepo = Get.find<AuthRepository>();
      final sessionResult = await ErrorHandler.execute(
        () async => await authRepo.getUser(),
        tag: 'VERIFY_SESSION',
      );

      await sessionResult.fold(
        (failure) async {
          if (failure.statusCode == 401) {
            storage.clearAll();
            FlutterNativeSplash.remove();
            Get.offAllNamed(Routes.ONBOARDING);
            Get.snackbar(
              "Phiên đăng nhập hết hạn",
              "Vui lòng đăng nhập lại",
              backgroundColor: Colors.orange,
              colorText: Colors.white,
            );
          } else {
            // Lỗi mạng hoặc server không phản hồi -> Coi như Offline
            if (!budgetService.isDataLoaded.value) {
              await budgetService.refreshData();
            }
            FlutterNativeSplash.remove();
            Get.offAllNamed(Routes.MAIN);
          }
        },
        (user) async {
          // Load settings from cloud (fire-and-forget)
          Get.find<SettingsService>().loadFromCloud();

          final rolloverRepo = Get.find<RolloverRepository>();
          final rolloverResult = await ErrorHandler.execute(
            () async => await rolloverRepo.checkRolloverState(),
            tag: 'CHECK_ROLLOVER',
          );

          await rolloverResult.fold(
            (failure) async {
              showErrorMessage("Lỗi Rollover", failure.message);
              if (!budgetService.isDataLoaded.value) {
                await budgetService.refreshData();
              }
              FlutterNativeSplash.remove();
              Get.offAllNamed(Routes.MAIN);
            },
            (result) async {
              if (result.state == RolloverState.newAccount) {
                await ErrorHandler.execute(
                  () async => await rolloverRepo.executeHardReset(user.$id),
                  tag: 'NEW_ACCOUNT_INIT',
                );
              } else if (result.state != RolloverState.noPending) {
                if (result.state == RolloverState.multiMonthGap) {
                  FlutterNativeSplash.remove();
                  Get.offAllNamed(
                    Routes.MULTI_MONTH_GAP,
                    arguments: {
                      'state': result.state,
                      'lastActiveMonthYear': result.lastActiveMonthYear,
                    },
                  );
                } else {
                  FlutterNativeSplash.remove();
                  Get.offAllNamed(
                    Routes.MONTH_END_REPORT,
                    arguments: {
                      'state': result.state,
                      'lastActiveMonthYear': result.lastActiveMonthYear,
                    },
                  );
                }
                return;
              }

              if (!budgetService.isDataLoaded.value) {
                await budgetService.refreshData();
              }
              FlutterNativeSplash.remove();
              Get.offAllNamed(Routes.MAIN);
            },
          );
        },
      );
    } catch (e) {
      // Production safety net: nếu có lỗi không mong đợi,
      // đảm bảo splash luôn được gỡ và app không bị treo
      debugPrint('❌ SplashController unexpected error: $e');
      FlutterNativeSplash.remove();
      storage.clearAll();
      Get.offAllNamed(Routes.ONBOARDING);
    }
  }
}
