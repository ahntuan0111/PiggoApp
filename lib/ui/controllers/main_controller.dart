import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:appintern/core/base/base_controller.dart';

class MainController extends BaseController with GetSingleTickerProviderStateMixin {
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

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}
