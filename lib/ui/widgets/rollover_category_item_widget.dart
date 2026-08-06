import 'package:flutter/material.dart';

class RolloverCategoryItemWidget extends StatelessWidget {
  final String title;
  final double amount;
  final bool isSurplus;

  const RolloverCategoryItemWidget({
    super.key,
    required this.title,
    required this.amount,
    required this.isSurplus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          isSurplus ? "+$amount đ" : "-${amount.abs()} đ",
          style: TextStyle(
            color: isSurplus ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
