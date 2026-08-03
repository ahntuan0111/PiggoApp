import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionDialog {
  static void show(String title, String message) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: const Text("Cài đặt", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
