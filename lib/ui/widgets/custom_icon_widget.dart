import 'package:flutter/material.dart';

class CustomIconWidget extends StatelessWidget {
  final String iconName;
  final double size;

  const CustomIconWidget({super.key, required this.iconName, this.size = 24});

  @override
  Widget build(BuildContext context) {
    if (iconName.endsWith('.png')) {
      final path = iconName.startsWith('assets/')
          ? iconName
          : 'assets/icons/$iconName';
      return Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback nếu ảnh lỗi hoặc không tìm thấy
          return Text('❓', style: TextStyle(fontSize: size));
        },
      );
    }

    // Fallback cho dữ liệu cũ trên Database (Vẫn là Emoji dạng Text)
    return Text(iconName, style: TextStyle(fontSize: size));
  }
}
