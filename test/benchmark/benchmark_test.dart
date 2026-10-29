import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:appintern/core/utils/local_rule_based_transaction_parser.dart';
import 'package:appintern/core/utils/transaction_router.dart';

void main() {
  test('Evaluate Benchmark Dataset on TransactionRouter & LocalParser', () async {
    final file = File('test/benchmark/benchmark_dataset.json');
    expect(await file.exists(), isTrue);

    final jsonContent = await file.readAsString();
    final data = jsonDecode(jsonContent) as Map<String, dynamic>;
    final cases = data['cases'] as List<dynamic>;

    int routeCorrectCount = 0;
    int parserAmountMatchCount = 0;
    final totalCases = cases.length;

    final categories = [
      'Ăn uống',
      'Di chuyển',
      'Mua sắm',
      'Hóa đơn & Tiện ích',
      'Nhà cửa',
      'Lương',
      'Thưởng',
      'Thu nhập khác',
    ];
    const currentTime = '2026-10-29T10:00:00.000Z';

    final stopwatch = Stopwatch()..start();

    for (final c in cases) {
      final input = c['input'] as String;
      final expectedRoute = c['expected_route'] as String;
      final expectedList = c['expected'] as List<dynamic>;

      // 1. Kiểm tra Router
      final decision = TransactionRouter.route(input);
      final actualRoute = decision.routeType.name;
      if (actualRoute == expectedRoute) {
        routeCorrectCount++;
      }

      // 2. Chạy Dart Parser baseline
      final parsed = LocalRuleBasedTransactionParser.parse(
        text: input,
        availableCategories: categories,
        currentTime: currentTime,
      );

      // So khớp số lượng và giá trị số tiền
      if (parsed.length == expectedList.length) {
        bool allAmountsMatch = true;
        for (int i = 0; i < parsed.length; i++) {
          final double actualAmt = (parsed[i]['amount'] as num).toDouble();
          final double expectedAmt = (expectedList[i]['amount'] as num).toDouble();
          if ((actualAmt - expectedAmt).abs() > 0.01) {
            allAmountsMatch = false;
            break;
          }
        }
        if (allAmountsMatch) {
          parserAmountMatchCount++;
        }
      }
    }

    stopwatch.stop();

    final routerAccuracy = (routeCorrectCount / totalCases) * 100;
    final parserAccuracy = (parserAmountMatchCount / totalCases) * 100;
    final avgLatencyUs = stopwatch.elapsedMicroseconds / totalCases;

    // In kết quả benchmark
    print('═════════════════════════════════════════════════════════════');
    print('📊 PIGO LAZY INPUT PARSER - BENCHMARK REPORT');
    print('═════════════════════════════════════════════════════════════');
    print('Tổng số mẫu test: $totalCases');
    print('Độ chính xác Router: ${routerAccuracy.toStringAsFixed(1)}% ($routeCorrectCount/$totalCases)');
    print('Độ chính xác Parser (Baseline): ${parserAccuracy.toStringAsFixed(1)}% ($parserAmountMatchCount/$totalCases)');
    print('Độ trễ trung bình mỗi câu: ${avgLatencyUs.toStringAsFixed(2)} µs (${(avgLatencyUs / 1000).toStringAsFixed(4)} ms)');
    print('═════════════════════════════════════════════════════════════');

    expect(routerAccuracy, greaterThanOrEqualTo(95.0));
    expect(parserAccuracy, greaterThanOrEqualTo(90.0));
  });
}

