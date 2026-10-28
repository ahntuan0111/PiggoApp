import 'package:flutter_test/flutter_test.dart';
import 'package:appintern/core/utils/local_rule_based_transaction_parser.dart';

void main() {
  group('LocalRuleBasedTransactionParser Tests', () {
    final categories = ['Ăn uống', 'Di chuyển', 'Mua sắm', 'Lương', 'Giải trí'];
    final currentTime = '2026-10-26T12:00:00.000Z';

    test('Parse đơn giản 1 câu chi tiêu', () {
      final res = LocalRuleBasedTransactionParser.parse(
        text: 'sáng ăn phở 45k',
        availableCategories: categories,
        currentTime: currentTime,
      );

      expect(res.length, 1);
      expect(res[0]['amount'], 45000.0);
      expect(res[0]['type'], 'outflow');
      expect(res[0]['categoryName'], 'Ăn uống');
      expect(res[0]['note'], contains('Ăn phở'));
    });

    test('Parse nhiều giao dịch nối bằng từ "với"', () {
      final res = LocalRuleBasedTransactionParser.parse(
        text: 'chiều trả tiền gửi xe 5k với mua trà sữa 35k',
        availableCategories: categories,
        currentTime: currentTime,
      );

      expect(res.length, 2);
      expect(res[0]['amount'], 5000.0);
      expect(res[0]['type'], 'outflow');
      expect(res[1]['amount'], 35000.0);
      expect(res[1]['type'], 'outflow');
      expect(res[1]['categoryName'], 'Ăn uống');
    });

    test('Parse thu nhập và từ lóng triệu/củ', () {
      final res = LocalRuleBasedTransactionParser.parse(
        text: 'hôm qua nhận lương 15 triệu',
        availableCategories: categories,
        currentTime: currentTime,
      );

      expect(res.length, 1);
      expect(res[0]['amount'], 15000000.0);
      expect(res[0]['type'], 'inflow');
      expect(res[0]['categoryName'], 'Lương');
      // Ngày phải bị lùi 1 ngày
      final date = DateTime.parse(res[0]['date']);
      expect(date.day, 25);
    });

    test('Parse từ lóng cành / xị', () {
      final res = LocalRuleBasedTransactionParser.parse(
        text: 'mua áo 200 cành',
        availableCategories: categories,
        currentTime: currentTime,
      );

      expect(res.length, 1);
      expect(res[0]['amount'], 200000.0);
      expect(res[0]['type'], 'outflow');
      expect(res[0]['categoryName'], 'Mua sắm');
    });
  });
}
