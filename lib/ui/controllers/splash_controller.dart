import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/routes/app_routes.dart';
import 'package:appintern/core/services/storage_service.dart';
import 'package:appintern/core/constants/app_keys.dart';
import 'package:appintern/data/repositories/auth_repository.dart';
import 'package:appintern/data/repositories/rollover_repository.dart';
import 'package:appintern/core/errors/error_handler.dart';
import 'package:appintern/core/services/network_service.dart';
import 'package:appintern/core/services/budget_service.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class SplashController extends BaseController {
  final storage = Get.find<StorageService>();

  @override
  void onReady() {
    super.onReady();
    _verifySessionAndFetchData();
  }

  Future<void> _verifySessionAndFetchData() async {
    final budgetService = Get.find<BudgetService>();
    final network = Get.find<NetworkService>();

    if (network.isOffline.value) {
      if (!budgetService.isDataLoaded.value) {
        await budgetService.refreshData(); // Load cache
      }
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
        storage.clearAll();
        Get.offAllNamed(Routes.ONBOARDING);
        Get.snackbar(
          "Phiên đăng nhập hết hạn",
          "Vui lòng đăng nhập lại (Do IP máy chủ thay đổi hoặc phiên hết hạn).",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      },
      (user) async {
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
                Get.offAllNamed(
                  Routes.MULTI_MONTH_GAP,
                  arguments: {
                    'state': result.state,
                    'lastActiveMonthYear': result.lastActiveMonthYear,
                  },
                );
              } else {
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
            Get.offAllNamed(Routes.MAIN);
          },
        );
      },
    );
  }
}
