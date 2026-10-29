import 'package:flutter_test/flutter_test.dart';
import 'package:appintern/data/models/hybrid_transaction_models.dart';
import 'package:appintern/core/utils/transaction_router.dart';
import 'package:appintern/core/utils/dart_validation_layer.dart';
import 'package:appintern/data/data_sources/local/local_ai_service_impl.dart';
import 'package:appintern/data/data_sources/local/ai_engines/on_device_ai_engine.dart';

void main() {
  group('TransactionRouter Tests', () {
    test('Empty text routes to Fast Path', () {
      final decision = TransactionRouter.route('');
      expect(decision.isFastPath, isTrue);
      expect(decision.candidateTokens, isEmpty);
    });

    test('Single clear transactions route to Fast Path (Dart Engine)', () {
      final simpleCases = [
        'an pho 45k',
        'mua ao 200 canh',
        'do xang 50',
        'mua do 1.500.000đ',
        'do xang 1,5 trieu',
        'mua do 20.000đ',
        'mua do 12.5k',
        'nhan luong 15 trieu',
        'an sang 35k',
        'tra sua 35k',
      ];

      for (final text in simpleCases) {
        final decision = TransactionRouter.route(text);
        expect(
          decision.isFastPath,
          isTrue,
          reason: 'Expected "$text" to route to Fast Path, got ${decision.routeType} (${decision.reason})',
        );
      }
    });

    test('Multi-transaction inputs route to Smart Path (AI On-Device)', () {
      final multiCases = [
        'do xang 50 an bun bo 55',
        'do xang 50k an bun bo 55k',
        '50 do xang 55 an bun bo',
        'an bun bo 55 do xang 50',
        'do xang 50 va an bun bo 55',
        'do xang 50 voi an bun bo 55',
        'do xang 50, an bun bo 55',
        'do xang 50 + an bun bo 55',
        'do xang 50; an bun bo 55',
        'thue nha 3 trieu tien dien 500k',
        'do xang 50 an bun bo 55 va mua ao 100',
      ];

      for (final text in multiCases) {
        final decision = TransactionRouter.route(text);
        expect(
          decision.isSmartPath,
          isTrue,
          reason: 'Expected "$text" to route to Smart Path, got ${decision.routeType} (${decision.reason})',
        );
        expect(decision.candidateTokens.length, greaterThanOrEqualTo(2));
      }
    });

    test('Inputs with quantity confusion route to Smart Path (AI On-Device)', () {
      final quantityCases = [
        'mua 2 ao 200k',
        'mua 3 ly cafe 90k',
        'mua 2 ao 200k an bun bo 55k',
      ];

      for (final text in quantityCases) {
        final decision = TransactionRouter.route(text);
        expect(
          decision.isSmartPath,
          isTrue,
          reason: 'Expected "$text" to route to Smart Path due to quantity confusion',
        );
      }
    });

    test('Inputs mixing income and expense keywords route to Smart Path', () {
      final mixedCases = [
        'nhan luong 15 trieu mua ao 200k',
        'nhan thuong 2 trieu tieu het 500k',
      ];

      for (final text in mixedCases) {
        final decision = TransactionRouter.route(text);
        expect(
          decision.isSmartPath,
          isTrue,
          reason: 'Expected "$text" with mixed income/expense to route to Smart Path',
        );
      }
    });
  });

  group('DartValidationLayer Tests (Anti-Hallucination & Guardrails)', () {
    const availableCategories = ['Ăn uống', 'Di chuyển', 'Mua sắm', 'Hóa đơn & Tiện ích', 'Lương'];
    const currentTime = '2026-10-29T10:00:00.000Z';

    test('Rejects hallucinated amounts that do not exist in raw input', () {
      const rawInput = 'mua banh mi 20k';
      final hallucinatedItems = [
        const RawAiTransactionItem(
          amountText: '500k', // Bị AI bịa ra
          note: 'Bánh mì',
          categoryHint: 'Ăn uống',
          type: 'outflow',
        ),
      ];

      final results = DartValidationLayer.validateAndEnrich(
        rawInput: rawInput,
        aiItems: hallucinatedItems,
        availableCategories: availableCategories,
        currentTime: currentTime,
      );

      // Phải loại bỏ hoàn toàn mốc tiền bịa
      expect(results, isEmpty);
    });

    test('Accepts grounded amounts and computes accurate deterministic values', () {
      const rawInput = 'mua 2 ao 200k an bun bo 55k';
      final aiItems = [
        const RawAiTransactionItem(
          amountText: '200k',
          note: 'Mua 2 áo',
          categoryHint: 'Mua sắm',
          type: 'outflow',
        ),
        const RawAiTransactionItem(
          amountText: '55k',
          note: 'Ăn bún bò',
          categoryHint: 'Ăn uống',
          type: 'outflow',
        ),
      ];

      final results = DartValidationLayer.validateAndEnrich(
        rawInput: rawInput,
        aiItems: aiItems,
        availableCategories: availableCategories,
        currentTime: currentTime,
      );

      expect(results.length, equals(2));

      expect(results[0]['amount'], equals(200000.0));
      expect(results[0]['note'], equals('Mua 2 áo'));
      expect(results[0]['categoryName'], equals('Mua sắm'));
      expect(results[0]['type'], equals('outflow'));

      expect(results[1]['amount'], equals(55000.0));
      expect(results[1]['note'], equals('Ăn bún bò'));
      expect(results[1]['categoryName'], equals('Ăn uống'));
      expect(results[1]['type'], equals('outflow'));
    });

    test('Leaves categoryName as null when category cannot be recognized', () {
      const rawInput = 'toi uu 50k';
      final aiItems = [
        const RawAiTransactionItem(
          amountText: '50k',
          note: 'Tối ưu',
          categoryHint: 'Không rõ',
          type: 'outflow',
        ),
      ];

      final results = DartValidationLayer.validateAndEnrich(
        rawInput: rawInput,
        aiItems: aiItems,
        availableCategories: availableCategories,
        currentTime: currentTime,
      );

      expect(results.length, equals(1));
      expect(results[0]['amount'], equals(50000.0));
      expect(results[0]['note'], equals('Tối ưu'));
      // Danh mục phải là null (chưa phân bổ) theo đúng yêu cầu người dùng
      expect(results[0]['categoryName'], isNull);
    });

    test('Correctly handles income type and aligns with salary category', () {
      const rawInput = 'nhan luong 15 trieu';
      final aiItems = [
        const RawAiTransactionItem(
          amountText: '15 trieu',
          note: 'Nhận lương tháng này',
          categoryHint: 'Lương',
          type: 'inflow',
        ),
      ];

      final results = DartValidationLayer.validateAndEnrich(
        rawInput: rawInput,
        aiItems: aiItems,
        availableCategories: availableCategories,
        currentTime: currentTime,
      );

      expect(results.length, equals(1));
      expect(results[0]['amount'], equals(15000000.0));
      expect(results[0]['type'], equals('inflow'));
      expect(results[0]['categoryName'], equals('Lương'));
    });

    test('Calculates relative dates correctly (hom qua -> previous day)', () {
      const rawInput = 'hom qua do xang 50k';
      final aiItems = [
        const RawAiTransactionItem(
          amountText: '50k',
          note: 'Đổ xăng hôm qua',
          categoryHint: 'Di chuyển',
          type: 'outflow',
        ),
      ];

      final results = DartValidationLayer.validateAndEnrich(
        rawInput: rawInput,
        aiItems: aiItems,
        availableCategories: availableCategories,
        currentTime: currentTime,
      );

      expect(results.length, equals(1));
      final dateStr = results[0]['date'] as String;
      final parsedDate = DateTime.parse(dateStr);
      expect(parsedDate.day, equals(28)); // 29 - 1 = 28
    });
  });

  group('Hybrid Flow End-to-End Tests (LocalAIServiceImpl with Mock AI Engine)', () {
    const availableCategories = ['Ăn uống', 'Di chuyển', 'Mua sắm', 'Hóa đơn & Tiện ích', 'Lương'];
    const currentTime = '2026-10-29T10:00:00.000Z';

    test('Executes Smart Path with AI Engine and returns validated transactions', () async {
      final mockEngine = MockAiEngine(
        response: [
          const RawAiTransactionItem(
            amountText: '200k',
            note: 'Mua 2 áo',
            categoryHint: 'Mua sắm',
            type: 'outflow',
          ),
        ],
      );

      final service = LocalAIServiceImpl();
      service.setAiEngine(mockEngine);

      // Input "mua 2 ao 200k" routes to Smart Path
      final result = await service.parseTransactionText(
        text: 'mua 2 ao 200k',
        availableCategories: availableCategories,
        currentTime: currentTime,
      );

      expect(result.length, equals(1));
      expect(result[0]['amount'], equals(200000.0));
      expect(result[0]['note'], equals('Mua 2 ao'));
      expect(result[0]['categoryName'], equals('Mua sắm'));
    });

    test('Falls back to LocalRuleBasedTransactionParser when AI Engine throws', () async {
      final mockEngine = MockAiEngine(shouldThrow: true);

      final service = LocalAIServiceImpl();
      service.setAiEngine(mockEngine);

      // Thất bại AI -> Tự động fallback sang Dart Engine đã pass 46 test cases
      final result = await service.parseTransactionText(
        text: 'do xang 50 an bun bo 55',
        availableCategories: availableCategories,
        currentTime: currentTime,
      );

      expect(result.length, equals(2));
      expect(result[0]['amount'], equals(50000.0));
      expect(result[1]['amount'], equals(55000.0));
    });

    test('Falls back to LocalRuleBasedTransactionParser when AI produces hallucinated amounts', () async {
      final mockEngine = MockAiEngine(
        response: [
          const RawAiTransactionItem(
            amountText: '9999k', // Ảo giác
            note: 'Ảo giác',
            categoryHint: 'Ăn uống',
            type: 'outflow',
          ),
        ],
      );

      final service = LocalAIServiceImpl();
      service.setAiEngine(mockEngine);

      final result = await service.parseTransactionText(
        text: 'do xang 50 an bun bo 55',
        availableCategories: availableCategories,
        currentTime: currentTime,
      );

      // Validation Layer từ chối 9999k -> fallback an toàn về Dart Parser
      expect(result.length, equals(2));
      expect(result[0]['amount'], equals(50000.0));
      expect(result[1]['amount'], equals(55000.0));
    });
  });
}

class MockAiEngine implements IOnDeviceAiEngine {
  final List<RawAiTransactionItem> response;
  final bool shouldThrow;

  MockAiEngine({
    this.response = const [],
    this.shouldThrow = false,
  });

  @override
  String get modelName => 'MockAiEngine';

  @override
  bool get isModelLoaded => true;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<List<RawAiTransactionItem>> parse(String input) async {
    if (shouldThrow) throw Exception('Inference timeout or crash');
    return response;
  }

  @override
  Future<void> unload() async {}
}
