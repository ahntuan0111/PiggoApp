import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:appintern/core/services/settings_service.dart';

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
    String numericString = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (numericString.isEmpty) {
      return newValue.copyWith(text: isNegative ? '-' : '');
    }

    final settings = Get.find<SettingsService>();
    final formatType = settings.numberFormat.value;
    String separator = _getSeparator(formatType);

    String newText = _formatNumberString(numericString, separator);
    if (isNegative) {
      newText = '-' + newText;
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  static String _getSeparator(String formatType) {
    switch (formatType) {
      case 'comma':
        return ',';
      case 'space':
        return ' ';
      case 'none':
        return '';
      case 'dot':
      default:
        return '.';
    }
  }

  static String _formatNumberString(String numStr, String separator) {
    if (separator.isEmpty) return numStr;
    return numStr.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}$separator',
    );
  }

  static String format(double amount) {
    final settings = Get.find<SettingsService>();
    final separator = _getSeparator(settings.numberFormat.value);
    final symbol = settings.currencySymbol;
    final position = settings.symbolPosition.value;
    
    String numStr = amount.abs().toStringAsFixed(0);
    numStr = _formatNumberString(numStr, separator);
    
    String sign = amount < 0 ? '-' : '';
    
    switch (position) {
      case 'before':
        return '$sign$symbol$numStr';
      case 'hidden':
        return '$sign$numStr';
      case 'after':
      default:
        return '$sign$numStr$symbol';
    }
  }

  static String formatCompact(double amount) {
    final settings = Get.find<SettingsService>();
    final position = settings.symbolPosition.value;
    final symbol = settings.currencySymbol;
    
    double absAmount = amount.abs();
    String numStr;
    if (absAmount >= 1e9) {
      numStr = '${(absAmount / 1e9).toStringAsFixed(1)}B';
    } else if (absAmount >= 1e6) {
      numStr = '${(absAmount / 1e6).toStringAsFixed(1)}M';
    } else if (absAmount >= 1e3) {
      numStr = '${(absAmount / 1e3).toStringAsFixed(0)}K';
    } else {
      numStr = absAmount.toStringAsFixed(0);
    }
    
    if (numStr.endsWith('.0B')) numStr = numStr.replaceAll('.0B', 'B');
    if (numStr.endsWith('.0M')) numStr = numStr.replaceAll('.0M', 'M');
    if (numStr.endsWith('.0K')) numStr = numStr.replaceAll('.0K', 'K');
    
    final separator = _getSeparator(settings.numberFormat.value);
    if (separator == ',') {
      numStr = numStr.replaceFirst('.', ',');
    } else if (separator == ' ') {
      numStr = numStr.replaceFirst('.', ',');
    }

    String sign = amount < 0 ? '-' : '';
    
    switch (position) {
      case 'before':
        return '$sign$symbol$numStr';
      case 'hidden':
        return '$sign$numStr';
      case 'after':
      default:
        return '$sign$numStr$symbol';
    }
  }

  static double parse(String formattedStr) {
    String numericPart = formattedStr.replaceAll(RegExp(r'[^\d\-]'), '');
    return double.tryParse(numericPart) ?? 0;
  }

  static String get symbol => Get.find<SettingsService>().currencySymbol;
}
