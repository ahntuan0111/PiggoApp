import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    bool isNegative = newValue.text.startsWith('-');
    String numericString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numericString.isEmpty) {
      return newValue.copyWith(text: isNegative ? '-' : '');
    }

    final formatter = NumberFormat('#,###', 'vi_VN');
    String newText = formatter.format(int.parse(numericString));
    if (isNegative) {
      newText = '-' + newText;
    }

    // Giữ con trỏ chuột luôn ở cuối chuỗi nhập
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  static String format(double amount) {
    String numStr = amount.toStringAsFixed(0);
    return numStr.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
