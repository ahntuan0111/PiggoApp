import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:appintern/core/base/base_controller.dart';

import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/core/routes/app_pages.dart';

class MainController extends BaseController with GetSingleTickerProviderStateMixin, BudgetAware {
  var selectedIndex = 0.obs;
  var isFabOpen = false.obs;
  late AnimationController animationController;

  @override
  void onInit() {
    super.onInit();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  void changeIndex(int index) {
    selectedIndex.value = index;
  }

  void toggleFab() {
    if (isFabOpen.value) {
      animationController.reverse();
      // Chờ animation chạy xong mới ẩn overlay
      Future.delayed(const Duration(milliseconds: 250), () {
        isFabOpen.value = false;
      });
    } else {
      isFabOpen.value = true;
      animationController.forward();
    }
  }

  bool canCreateTransaction() {
    // Kiem tra truc tiep tu BudgetService
    return budgetService.categories.isNotEmpty;
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}
