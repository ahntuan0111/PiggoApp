import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Dialog hiển thị khi AI không thể phân tích nội dung giọng nói.
class AiParseErrorDialog extends StatelessWidget {
  const AiParseErrorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text(
            "Không thể phân tích",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: const Text(
        "Giọng nói có thể không rõ ràng, chứa từ ngữ không phù hợp hoặc kết nối mạng bị gián đoạn. Vui lòng thử lại với câu khác.",
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text(
            "Đã hiểu",
            style: TextStyle(
              color: Color(0xFFEBC14F),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
