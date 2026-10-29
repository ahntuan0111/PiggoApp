import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:appintern/data/data_sources/local/local_ai_service_impl.dart';
import 'package:appintern/core/services/network_service.dart';

// Mock NetworkService to simulate Online / Offline states
class MockNetworkService extends GetxService implements NetworkService {
  @override
  final RxBool isOffline = false.obs;

  @override
  Future<void> checkConnection() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalAIServiceImpl aiService;
  late MockNetworkService mockNetworkService;

  final testCategories = [
    'Ăn uống',
    'Di chuyển',
    'Mua sắm',
    'Hóa đơn',
    'Giải trí',
    'Lương',
  ];
  final currentTime = '2026-10-29T10:00:00.000Z';

  setUp(() async {
    Get.reset();
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {}

    mockNetworkService = MockNetworkService();
    Get.put<NetworkService>(mockNetworkService);
    aiService = Get.put<LocalAIServiceImpl>(LocalAIServiceImpl());
  });

  tearDown(() {
    Get.reset();
  });

  group('On-Device First Architecture Tests (LocalAIServiceImpl)', () {
    test('T1: Input đơn giản "ăn phở 45k" được bóc tách 100% On-Device (Tầng 1)', () async {
      mockNetworkService.isOffline.value = false; // Online

      final results = await aiService.parseTransactionText(
        text: 'sáng ăn phở 45k',
        availableCategories: testCategories,
        currentTime: currentTime,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.length, 1);
      expect(results[0]['amount'], 45000.0);
      expect(results[0]['type'], 'outflow');
      expect(results[0]['categoryName'], 'Ăn uống');
    });

    test('T2: Input từ lóng "2 củ" được bóc tách On-Device (Tầng 1)', () async {
      final results = await aiService.parseTransactionText(
        text: 'mua áo 2 củ',
        availableCategories: testCategories,
        currentTime: currentTime,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results[0]['amount'], 2000000.0);
      expect(results[0]['type'], 'outflow');
      expect(results[0]['categoryName'], 'Mua sắm');
    });

    test('T3: Input thu nhập "nhận lương 15 triệu" được bóc tách On-Device (Tầng 1)', () async {
      final results = await aiService.parseTransactionText(
        text: 'hôm nay nhận lương 15 triệu',
        availableCategories: testCategories,
        currentTime: currentTime,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results[0]['amount'], 15000000.0);
      expect(results[0]['type'], 'inflow');
      expect(results[0]['categoryName'], 'Lương');
    });

    test('T4: Input nhiều giao dịch "cà phê 25k và bánh mì 15k" xử lý On-Device', () async {
      final results = await aiService.parseTransactionText(
        text: 'cà phê 25k và bánh mì 15k',
        availableCategories: testCategories,
        currentTime: currentTime,
      );

      expect(results.length, 2);
      expect(results[0]['amount'], 25000.0);
      expect(results[1]['amount'], 15000.0);
    });

    test('T5: Input rỗng trả về danh sách rỗng', () async {
      final results = await aiService.parseTransactionText(
        text: '   ',
        availableCategories: testCategories,
        currentTime: currentTime,
      );

      expect(results.isEmpty, isTrue);
    });

    test('T11 & T13: Khi OFFLINE, input không có số tiền trả về kết quả mặc định On-Device an toàn', () async {
      mockNetworkService.isOffline.value = true; // Chế độ máy bay / mất mạng

      final results = await aiService.parseTransactionText(
        text: 'đi siêu thị mua đồ ăn',
        availableCategories: testCategories,
        currentTime: currentTime,
      );

      // Phải trả về kết quả an toàn từ parser On-Device, không gọi Cloud và không văng Exception
      expect(results.isNotEmpty, isTrue);
      expect(results[0]['amount'], 0.0);
      expect(results[0]['note'], contains('đi siêu thị mua đồ ăn'));
    });

    test('T11: Khi OFFLINE, input có số tiền vẫn nhận diện chính xác qua On-Device', () async {
      mockNetworkService.isOffline.value = true;

      final results = await aiService.parseTransactionText(
        text: 'uống cafe 30k',
        availableCategories: testCategories,
        currentTime: currentTime,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results[0]['amount'], 30000.0);
      expect(results[0]['categoryName'], 'Ăn uống');
    });
  });
}
