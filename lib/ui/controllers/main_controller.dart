import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appintern/core/base/base_controller.dart';
import 'package:appintern/core/mixins/budget_aware_mixin.dart';
import 'package:appintern/ui/controllers/smart_input_controller.dart';

class MainController extends BaseController
    with GetSingleTickerProviderStateMixin, BudgetAware {
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

  Future<void> openCameraReceiptScan() async {
    toggleFab();
    await Future.delayed(const Duration(milliseconds: 260));
    final smartInputController = Get.find<SmartInputController>();
    await smartInputController.pickAndProcessReceipt(ImageSource.camera);
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}
